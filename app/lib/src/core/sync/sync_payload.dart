/// What actually travels: the per-account sync payload, its canonical hash,
/// the remote sidecar document, and the SDA-compatible remote manifest.
///
/// The remote directory is a standard SDA encrypted folder — `manifest.json`
/// plus one base64-ciphertext `*.maFile` per account — so SDA, steamguard-cli
/// and AVA's own folder import can all read it. The only AVA-specific file is
/// the sidecar `ava.sync.json` (revisions, tombstones, devices), which SDA
/// never touches.
///
/// Everything here is pure: no Flutter, no IO, no network.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import '../crypto/ma_file_crypto.dart';
import '../models/manifest.dart';
import '../models/steam_guard_account.dart';

/// Remote filename of the sidecar. Chosen to sort next to manifest.json and
/// to be self-describing to someone browsing their WebDAV folder.
const String kSyncSidecarFilename = 'ava.sync.json';

/// Remote filename of the SDA manifest.
const String kSyncManifestFilename = 'manifest.json';

/// Minimum sync passphrase length the UI enforces (2026-08-12 user decision:
/// 8). The remote KDF is SDA's PBKDF2-SHA1/50000 — the compatibility price —
/// so the passphrase carries the entropy; the setup screen still nudges
/// longer via the strength bar.
const int kSyncPassphraseMinLength = 8;

/// The plaintext inside the remote manifest's `passkey_check` token, used to
/// verify the sync passphrase even when the remote holds zero accounts.
/// Distinct from the local PIN check constant so the two can never be
/// mistaken for one another in a bug report.
const String kSyncPasskeyCheckPlaintext = 'AVA-SYNC-PASSKEY-CHECK';

/// The JSON payload one account contributes to sync.
///
/// Starts from [SteamGuardAccount.toExportJson] (which already owns the
/// include-password decision) and strips the session tokens: sessions are
/// device-bound live data whose refresh tokens rotate — sharing one between
/// devices makes them invalidate each other. The password is static, and a
/// new device rebuilds its own session from it lazily (AutoLogin).
///
/// The `Session` block itself stays, reduced to its `SteamID`: that id is the
/// account's identity (the maFile format keeps it nowhere else), and a
/// session-less maFile imports as a synthetic-id code-only account — which
/// would make every pull look like a brand-new account.
Map<String, dynamic> syncPayloadJson(SteamGuardAccount account,
    {required bool includePassword}) {
  final json = account.toExportJson(includePassword: includePassword);
  json['Session'] = {'SteamID': account.steamId};
  return json;
}

/// Canonical JSON: map keys sorted recursively, no whitespace. Two devices
/// serializing the same logical payload must produce identical bytes, or
/// hash comparison would report phantom changes.
String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonicalize(value[k])};
  }
  if (value is List) return [for (final v in value) _canonicalize(v)];
  return value;
}

/// Content hash of a payload, as lowercase hex SHA-256 of its canonical JSON.
String payloadHash(Map<String, dynamic> payload) =>
    sha256.convert(utf8.encode(canonicalJson(payload))).toString();

/// Remote filename for [steamId] at [rev]. Revision-suffixed so pushes never
/// overwrite a file another device's sidecar still references; the manifest
/// entry names the file, so the folder stays a valid SDA folder.
String syncMaFileName(int steamId, int rev) => '$steamId.r$rev.maFile';

/// Encrypts [payload] for the remote folder. Returns the base64 ciphertext
/// plus the fresh salt/IV that must go into the remote manifest entry —
/// exactly SDA's scheme (PBKDF2-HMAC-SHA1/50000 + AES-256-CBC), which is what
/// keeps the folder readable by SDA itself.
({String ciphertext, String salt, String iv}) encryptSyncPayload(
    String passphrase, Map<String, dynamic> payload) {
  final salt = MaFileCrypto.getRandomSalt();
  final iv = MaFileCrypto.getInitializationVector();
  final ciphertext =
      MaFileCrypto.encrypt(passphrase, salt, iv, jsonEncode(payload));
  return (ciphertext: ciphertext, salt: salt, iv: iv);
}

/// Decrypts one remote maFile. Returns null on a wrong passphrase or corrupt
/// blob — the caller decides which it is (same judgement as the SDA import:
/// everything failing at once is a wrong passphrase, one failing is a corrupt
/// file).
Map<String, dynamic>? decryptSyncPayload(
    String passphrase, String salt, String iv, String ciphertext) {
  final text = MaFileCrypto.decrypt(passphrase, salt, iv, ciphertext);
  if (text == null) return null;
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Builds the remote `manifest.json` for the current remote account set.
/// A standard SDA manifest (encrypted, per-entry salt/iv) with one AVA
/// extension: `passkey_check`, so a passphrase can be verified against an
/// account-less remote. SDA ignores unknown keys.
String buildRemoteManifest(
    Map<int, SyncRemoteAccount> accounts, String passkeyCheck) {
  final manifest = Manifest(
    encrypted: true,
    firstRun: false,
    passkeyCheck: passkeyCheck,
    entries: [
      for (final e in accounts.entries)
        ManifestEntry(
          steamId: e.key,
          filename: e.value.filename,
          salt: e.value.salt,
          iv: e.value.iv,
        ),
    ],
  );
  return jsonEncode(manifest.toJson());
}

/// Mints a fresh `passkey_check` token (`salt|iv|ciphertext` of a known
/// plaintext) for [passphrase].
String buildPasskeyCheck(String passphrase) {
  final salt = MaFileCrypto.getRandomSalt();
  final iv = MaFileCrypto.getInitializationVector();
  final ct =
      MaFileCrypto.encrypt(passphrase, salt, iv, kSyncPasskeyCheckPlaintext);
  return '$salt|$iv|$ct';
}

/// Verifies [passphrase] against a manifest `passkey_check` token. Null when
/// the token is malformed (older remote) — then the caller falls back to
/// test-decrypting an account file.
bool? verifyPasskeyCheck(String passphrase, String? token) {
  if (token == null) return null;
  final parts = token.split('|');
  if (parts.length != 3) return null;
  return MaFileCrypto.decrypt(passphrase, parts[0], parts[1], parts[2]) ==
      kSyncPasskeyCheckPlaintext;
}

/// One live account as the remote sidecar records it.
class SyncRemoteAccount {
  /// Lamport revision: bumped past everything the pusher had seen.
  final int rev;

  /// [payloadHash] of the plaintext payload — comparable across devices.
  final String hash;

  /// The revision-suffixed ciphertext filename this entry lives in.
  final String filename;

  /// Crypto params, mirrored from the manifest entry so the sidecar alone
  /// carries everything a pull needs (one GET fewer, and no risk of reading
  /// a manifest that a mid-crash committer left one commit behind).
  final String salt;
  final String iv;

  const SyncRemoteAccount({
    required this.rev,
    required this.hash,
    required this.filename,
    required this.salt,
    required this.iv,
  });

  factory SyncRemoteAccount.fromJson(Map<String, dynamic> json) =>
      SyncRemoteAccount(
        rev: (json['rev'] as num?)?.toInt() ?? 0,
        hash: (json['hash'] as String?) ?? '',
        filename: (json['filename'] as String?) ?? '',
        salt: (json['salt'] as String?) ?? '',
        iv: (json['iv'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'rev': rev,
        'hash': hash,
        'filename': filename,
        'salt': salt,
        'iv': iv,
      };
}

/// A deletion marker. Kept (never expired) so a device that was offline for
/// months still learns about the delete instead of resurrecting the account.
/// The payload is tiny; a hundred tombstones cost less than one resurrection.
class SyncTombstone {
  /// Strictly greater than the deleted account's last live rev.
  final int rev;

  /// ISO-8601 UTC, display only — ordering always uses [rev].
  final String? deletedAt;

  /// Device id that performed the delete, display only.
  final String? device;

  const SyncTombstone({required this.rev, this.deletedAt, this.device});

  factory SyncTombstone.fromJson(Map<String, dynamic> json) => SyncTombstone(
        rev: (json['rev'] as num?)?.toInt() ?? 0,
        deletedAt: json['deleted_at'] as String?,
        device: json['device'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'rev': rev,
        if (deletedAt != null) 'deleted_at': deletedAt,
        if (device != null) 'device': device,
      };
}

/// A device that has committed to this remote, display/debug only.
class SyncDeviceInfo {
  final String name;
  final String? lastSyncAt;
  const SyncDeviceInfo({required this.name, this.lastSyncAt});

  factory SyncDeviceInfo.fromJson(Map<String, dynamic> json) => SyncDeviceInfo(
        name: (json['name'] as String?) ?? '',
        lastSyncAt: json['last_sync'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (lastSyncAt != null) 'last_sync': lastSyncAt,
      };
}

/// The sidecar document (`ava.sync.json`): the remote's source of truth for
/// revisions, tombstones and settings that must agree across devices.
///
/// Deliberately name-free: account display names stay out of it. The
/// manifest already leaks steamids (SDA format, unavoidable); adding names
/// would widen what a breached server operator learns for zero sync value.
class SyncSidecar {
  static const int currentVersion = 1;

  final int version;

  /// Bumped when the sync passphrase changes; a device holding a stale
  /// passphrase sees the mismatch and asks the user instead of reporting
  /// every file as corrupt.
  final int passphraseEpoch;

  /// Whether the payloads currently on the remote carry account passwords.
  /// The device that flips the toggle re-pushes everything and updates this;
  /// other devices adopt it into their local config.
  final bool includePasswords;

  /// Mirror of the manifest's `passkey_check` token, so a routine round can
  /// verify the passphrase from the sidecar alone without fetching the
  /// manifest. The manifest keeps its copy for SDA-side readers.
  final String? passkeyCheck;

  final Map<int, SyncRemoteAccount> accounts;
  final Map<int, SyncTombstone> tombstones;
  final Map<String, SyncDeviceInfo> devices;

  /// The synced app-settings document (curated appearance/behavior
  /// preferences), same envelope as an account entry: revision, payload
  /// hash, and the crypto params of its rev-suffixed ciphertext file.
  /// Null when no device has pushed settings yet.
  final SyncRemoteAccount? settings;

  const SyncSidecar({
    this.version = currentVersion,
    this.passphraseEpoch = 1,
    this.includePasswords = true,
    this.passkeyCheck,
    this.accounts = const {},
    this.tombstones = const {},
    this.devices = const {},
    this.settings,
  });

  factory SyncSidecar.fromJson(Map<String, dynamic> json) {
    Map<int, T> byId<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
      final out = <int, T>{};
      if (raw is Map) {
        for (final e in raw.entries) {
          final id = int.tryParse(e.key.toString());
          final v = e.value;
          if (id != null && v is Map) {
            out[id] = parse(v.cast<String, dynamic>());
          }
        }
      }
      return out;
    }

    final devices = <String, SyncDeviceInfo>{};
    final rawDevices = json['devices'];
    if (rawDevices is Map) {
      for (final e in rawDevices.entries) {
        final v = e.value;
        if (v is Map) {
          devices[e.key.toString()] =
              SyncDeviceInfo.fromJson(v.cast<String, dynamic>());
        }
      }
    }

    return SyncSidecar(
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
      passphraseEpoch: (json['passphrase_epoch'] as num?)?.toInt() ?? 1,
      includePasswords: json['include_passwords'] != false,
      passkeyCheck: json['passkey_check'] as String?,
      accounts: byId(json['accounts'], SyncRemoteAccount.fromJson),
      tombstones: byId(json['tombstones'], SyncTombstone.fromJson),
      devices: devices,
      settings: json['settings'] is Map
          ? SyncRemoteAccount.fromJson(
              (json['settings'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  static SyncSidecar parse(String text) =>
      SyncSidecar.fromJson(jsonDecode(text) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
        'version': version,
        'passphrase_epoch': passphraseEpoch,
        'include_passwords': includePasswords,
        if (passkeyCheck != null) 'passkey_check': passkeyCheck,
        'accounts': {
          for (final e in accounts.entries) '${e.key}': e.value.toJson()
        },
        'tombstones': {
          for (final e in tombstones.entries) '${e.key}': e.value.toJson()
        },
        'devices': {
          for (final e in devices.entries) e.key: e.value.toJson()
        },
        if (settings != null) 'settings': settings!.toJson(),
      };

  String serialize() => jsonEncode(toJson());

  SyncSidecar copyWith({
    int? passphraseEpoch,
    bool? includePasswords,
    String? passkeyCheck,
    Map<int, SyncRemoteAccount>? accounts,
    Map<int, SyncTombstone>? tombstones,
    Map<String, SyncDeviceInfo>? devices,
    SyncRemoteAccount? settings,
  }) =>
      SyncSidecar(
        version: version,
        passphraseEpoch: passphraseEpoch ?? this.passphraseEpoch,
        includePasswords: includePasswords ?? this.includePasswords,
        passkeyCheck: passkeyCheck ?? this.passkeyCheck,
        accounts: accounts ?? this.accounts,
        tombstones: tombstones ?? this.tombstones,
        devices: devices ?? this.devices,
        settings: settings ?? this.settings,
      );
}
