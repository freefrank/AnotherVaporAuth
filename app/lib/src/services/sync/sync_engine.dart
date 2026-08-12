/// The sync orchestrator: runs rounds (fetch → plan → execute → commit),
/// owns the conflict list, the trash, and the status the UI renders.
///
/// Design rules it enforces (from the spec):
///  - Sync is the library's shadow, never its gate: nothing here blocks an
///    account operation, errors surface as status, not dialogs.
///  - Every destructive step (remote tombstone applied locally, either side
///    of a conflict resolution) writes the losing payload to the trash first.
///  - The sidecar PUT is the commit point, guarded by If-Match; a 412 means
///    another device won — re-pull, re-merge, retry (bounded), never
///    overwrite blind.
///
/// The engine knows nothing about Flutter or Riverpod. Its window into the
/// account store is [SyncAccountsPort]; providers adapt it to AppController
/// and tests fake it in memory.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart' show IterableExtension;

import '../../core/models/steam_guard_account.dart';
import '../../core/sync/sync_payload.dart';
import '../../core/sync/sync_planner.dart';
import '../../core/sync/sync_transport.dart';
import '../debug_log.dart';
import 'sync_config_store.dart';
import 'sync_trash.dart';

/// The engine's window into the local account store.
abstract class SyncAccountsPort {
  /// The decrypted account list, or null while locked / not bootstrapped.
  List<SteamGuardAccount>? snapshot();

  /// Imports/overwrites one account from a pulled payload (standard maFile
  /// JSON). Must merge like a file import: keep the local session and local
  /// enrichment when the payload carries none.
  Future<void> applyRemote(Map<String, dynamic> payload);

  /// Removes one account locally (the engine has already trashed it).
  Future<void> removeAccount(int steamId);
}

typedef SyncTransportFactory = SyncTransport Function(
    SyncConfig config, String webdavPassword);

enum SyncErrorKind {
  none,
  network,
  auth,
  tls,
  server,

  /// The stored passphrase no longer opens the remote (changed elsewhere,
  /// or secure storage lost it) — the UI asks for it again.
  passphrase,
  io,
}

/// One unresolved conflict, with both payloads already in hand so the
/// compare UI never needs the network.
class SyncConflictItem {
  final int steamId;
  final SyncConflictKind kind;
  final Map<String, dynamic>? localPayload;
  final Map<String, dynamic>? remotePayload;
  final SyncRemoteAccount? remote;
  final SyncTombstone? tombstone;

  const SyncConflictItem({
    required this.steamId,
    required this.kind,
    this.localPayload,
    this.remotePayload,
    this.remote,
    this.tombstone,
  });

  String? get accountName =>
      (localPayload?['account_name'] ?? remotePayload?['account_name'])
          as String?;
}

class SyncEngineStatus {
  final bool configured;
  final bool syncing;
  final DateTime? lastSyncAt;
  final SyncErrorKind errorKind;
  final String? errorDetail;
  final bool needsPassphrase;
  final bool conditionalUnsupported;
  final List<SyncConflictItem> conflicts;
  final int lastPushed;
  final int lastPulled;

  const SyncEngineStatus({
    this.configured = false,
    this.syncing = false,
    this.lastSyncAt,
    this.errorKind = SyncErrorKind.none,
    this.errorDetail,
    this.needsPassphrase = false,
    this.conditionalUnsupported = false,
    this.conflicts = const [],
    this.lastPushed = 0,
    this.lastPulled = 0,
  });

  bool get hasError => errorKind != SyncErrorKind.none;

  SyncEngineStatus copyWith({
    bool? configured,
    bool? syncing,
    DateTime? lastSyncAt,
    SyncErrorKind? errorKind,
    String? errorDetail,
    bool? needsPassphrase,
    bool? conditionalUnsupported,
    List<SyncConflictItem>? conflicts,
    int? lastPushed,
    int? lastPulled,
  }) =>
      SyncEngineStatus(
        configured: configured ?? this.configured,
        syncing: syncing ?? this.syncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        errorKind: errorKind ?? this.errorKind,
        errorDetail: errorDetail == null && errorKind == SyncErrorKind.none
            ? null
            : (errorDetail ?? this.errorDetail),
        needsPassphrase: needsPassphrase ?? this.needsPassphrase,
        conditionalUnsupported:
            conditionalUnsupported ?? this.conditionalUnsupported,
        conflicts: conflicts ?? this.conflicts,
        lastPushed: lastPushed ?? this.lastPushed,
        lastPulled: lastPulled ?? this.lastPulled,
      );
}

/// Counts for the wizard's first-merge preview.
class SyncPreview {
  final int pulls;
  final int pushes;
  final int conflicts;
  final List<String> pullNames;
  const SyncPreview({
    required this.pulls,
    required this.pushes,
    required this.conflicts,
    this.pullNames = const [],
  });
}

class SyncEngine {
  final SyncConfigStore configStore;
  final SyncAccountsPort accounts;
  final SyncTrash trash;
  final SyncTransportFactory transportFactory;
  final Future<String> Function() deviceId;
  final DateTime Function() now;

  /// Debounce for change-triggered rounds; long enough to batch a burst of
  /// store writes (import of twenty accounts), short enough to feel live.
  final Duration debounce;

  SyncEngine({
    required this.configStore,
    required this.accounts,
    required this.trash,
    required this.transportFactory,
    required this.deviceId,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 5),
  }) : now = now ?? DateTime.now;

  final _statusController = StreamController<SyncEngineStatus>.broadcast();
  SyncEngineStatus _status = const SyncEngineStatus();
  SyncEngineStatus get status => _status;
  Stream<SyncEngineStatus> get statusStream => _statusController.stream;

  void _publish(SyncEngineStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  Timer? _debounceTimer;
  bool _started = false;

  /// Serializes rounds. Each caller's future completes after its own round,
  /// so `await syncNow()` always means "a round that saw my state ran" —
  /// even when another round was in flight when it was called.
  Future<void> _rounds = Future<void>.value();

  /// Max commit-race retries before giving up the round (the next trigger
  /// tries again anyway).
  static const int _maxCommitRetries = 3;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    unawaited(trash.purgeExpired());
    final config = await configStore.loadConfig();
    _publish(_status.copyWith(
      configured: config != null,
      conditionalUnsupported: config?.conditionalUnsupported ?? false,
    ));
  }

  void dispose() {
    _debounceTimer?.cancel();
    _statusController.close();
  }

  /// Called whenever the account list may have changed (any store write).
  /// Debounced; no-op rounds are cheap (hash comparison only).
  void notifyAccountsChanged() {
    if (!_status.configured) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(_autoSync());
    });
  }

  Future<void> _autoSync() async {
    final config = await configStore.loadConfig();
    if (config == null || !config.autoSync) return;
    await syncNow();
  }

  /// Runs one full sync round, queued behind any round already in flight.
  Future<void> syncNow() {
    final run = _rounds.then((_) => _runRound());
    _rounds = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _runRound() async {
    final config = await configStore.loadConfig();
    if (config == null) {
      _publish(_status.copyWith(configured: false));
      return;
    }
    final local = accounts.snapshot();
    if (local == null) return; // locked — nothing to compare against

    final webdavPassword = await configStore.loadWebdavPassword();
    final passphrase = await configStore.loadPassphrase();
    if (webdavPassword == null || passphrase == null || passphrase.isEmpty) {
      _publish(_status.copyWith(
        configured: true,
        needsPassphrase: true,
        errorKind: SyncErrorKind.passphrase,
        errorDetail: 'missing stored sync secrets',
      ));
      return;
    }

    _publish(_status.copyWith(
      configured: true,
      syncing: true,
      errorKind: SyncErrorKind.none,
      conditionalUnsupported: config.conditionalUnsupported,
    ));

    SyncTransport? transport;
    try {
      transport = transportFactory(config, webdavPassword);
      var outcome = await _attemptRound(transport, config, passphrase);
      var retries = 0;
      while (outcome == _RoundOutcome.commitRaced &&
          retries < _maxCommitRetries) {
        retries++;
        dlog('sync: commit raced, retry $retries/$_maxCommitRetries');
        outcome = await _attemptRound(transport, config, passphrase);
      }
      if (outcome == _RoundOutcome.commitRaced) {
        _publish(_status.copyWith(
          syncing: false,
          errorKind: SyncErrorKind.server,
          errorDetail: 'commit kept racing after $_maxCommitRetries retries',
        ));
      }
    } on SyncTransportException catch (e) {
      _publish(_status.copyWith(
        syncing: false,
        errorKind: switch (e) {
          SyncAuthError() => SyncErrorKind.auth,
          SyncTlsUntrusted() => SyncErrorKind.tls,
          SyncNetworkError() => SyncErrorKind.network,
          _ => SyncErrorKind.server,
        },
        errorDetail: e.message,
      ));
      dlog('sync: failed: $e');
    } catch (e) {
      _publish(_status.copyWith(
          syncing: false,
          errorKind: SyncErrorKind.io,
          errorDetail: '$e'));
      dlog('sync: failed: $e');
    } finally {
      transport?.close();
    }
  }

  Future<_RoundOutcome> _attemptRound(
      SyncTransport transport, SyncConfig config, String passphrase) async {
    final local = accounts.snapshot();
    if (local == null) return _RoundOutcome.done;

    // 1. Fetch the sidecar — the remote's source of truth.
    final sidecarFile = await transport.getFile(kSyncSidecarFilename);
    var remote = const SyncSidecar();
    var remoteExists = false;
    if (sidecarFile != null) {
      remoteExists = true;
      try {
        remote = SyncSidecar.parse(utf8.decode(sidecarFile.bytes));
      } catch (e) {
        _publish(_status.copyWith(
          syncing: false,
          errorKind: SyncErrorKind.server,
          errorDetail: 'remote sidecar is unreadable: $e',
        ));
        return _RoundOutcome.done;
      }
    }

    // 2. Passphrase sanity against the remote before touching anything.
    // Skipped when this device is the one changing the passphrase (its local
    // epoch is ahead) — the old remote token is expected to fail then.
    if (remoteExists && config.passphraseEpoch <= remote.passphraseEpoch) {
      final check = verifyPasskeyCheck(passphrase, remote.passkeyCheck);
      if (check == false) {
        _publish(_status.copyWith(
          syncing: false,
          needsPassphrase: true,
          errorKind: SyncErrorKind.passphrase,
          errorDetail: 'stored passphrase no longer opens the remote',
        ));
        return _RoundOutcome.done;
      }
      // The passphrase still opens the remote but the epoch moved (a
      // passphrase "change" elsewhere to the same phrase, or a re-setup):
      // adopt the remote epoch quietly.
      if (check == true && remote.passphraseEpoch > config.passphraseEpoch) {
        await configStore.saveConfig(
            config.copyWith(passphraseEpoch: remote.passphraseEpoch));
      }
    }

    // 3. The include-passwords flag must agree across devices. A local
    // pending toggle wins (it re-pushes everything); otherwise the remote's
    // value is adopted — the device that flipped it last committed it.
    var effectiveConfig = config;
    if (remoteExists &&
        remote.includePasswords != config.syncPasswords &&
        !config.forcePushPending) {
      effectiveConfig = config.copyWith(syncPasswords: remote.includePasswords);
      await configStore.saveConfig(effectiveConfig);
    }
    final includePasswords = effectiveConfig.syncPasswords;

    // 4. Plan.
    final state = await configStore.loadState();
    final byId = {for (final a in local) a.steamId: a};
    final payloads = {
      for (final a in local)
        a.steamId: syncPayloadJson(a, includePassword: includePasswords)
    };
    final localHashes = {
      for (final e in payloads.entries) e.key: payloadHash(e.value)
    };
    final plan = planSync(
      localHashes: localHashes,
      base: state.base,
      tombstonesSeen: state.tombstonesSeen,
      remote: remote,
      forcePushAll: effectiveConfig.forcePushPending,
    );

    final newBase = Map<int, SyncBaseEntry>.of(state.base);
    final newSeen = Map<int, int>.of(state.tombstonesSeen);
    var pushed = 0, pulled = 0;

    // 5. Pulls first (reads before writes; a failed pull aborts the round
    // before anything was mutated remotely).
    final conflicts = <SyncConflictItem>[];
    var pullDecryptFailures = 0;
    var pullDecryptAttempts = 0;
    for (final pull in plan.pulls) {
      final file = await transport.getFile(pull.remote.filename);
      if (file == null) {
        // Missing file ≠ wrong passphrase: an interrupted committer can
        // leave a sidecar entry whose payload never landed. Skip; the next
        // committing device repairs the reference.
        dlog('sync: pull ${pull.steamId}: file missing, skipped');
        continue;
      }
      pullDecryptAttempts++;
      final payload = decryptSyncPayload(passphrase, pull.remote.salt,
          pull.remote.iv, utf8.decode(file.bytes));
      if (payload == null) {
        pullDecryptFailures++;
        dlog('sync: pull ${pull.steamId} unreadable, skipped');
        continue;
      }
      await accounts.applyRemote(payload);
      newBase[pull.steamId] =
          SyncBaseEntry(rev: pull.remote.rev, hash: pull.remote.hash);
      pulled++;
    }
    // Every attempted decrypt failing = wrong passphrase (same judgement as
    // the SDA import); scattered failures = corrupt entries, reported soft.
    if (pullDecryptAttempts > 0 &&
        pullDecryptFailures == pullDecryptAttempts) {
      _publish(_status.copyWith(
        syncing: false,
        needsPassphrase: true,
        errorKind: SyncErrorKind.passphrase,
        errorDetail: 'no remote account could be decrypted',
      ));
      return _RoundOutcome.done;
    }

    // 6. Apply remote deletions locally — trash first, then remove.
    for (final del in plan.localDeletes) {
      final acc = byId[del.steamId];
      if (acc != null) {
        final ok = await trash.put(
          steamId: del.steamId,
          accountName: acc.accountName,
          payload: syncPayloadJson(acc, includePassword: true),
          reason: SyncTrashReason.remoteDelete,
          passphrase: passphrase,
        );
        if (!ok) {
          // No trash copy → no delete. The account will re-conflict next
          // round; losing secrets to a full disk is the one unacceptable
          // outcome.
          dlog('sync: trash write failed, refusing to delete ${del.steamId}');
          continue;
        }
        await accounts.removeAccount(del.steamId);
      }
      newBase.remove(del.steamId);
      newSeen[del.steamId] = del.tombstone.rev;
    }

    // 7. Conflicts: fetch the remote side now so the UI can compare offline.
    for (final c in plan.conflicts) {
      Map<String, dynamic>? remotePayload;
      if (c.remote != null) {
        remotePayload = await _fetchPayload(transport, c.remote!, passphrase);
      }
      final acc = byId[c.steamId];
      conflicts.add(SyncConflictItem(
        steamId: c.steamId,
        kind: c.kind,
        localPayload: acc == null
            ? null
            : syncPayloadJson(acc, includePassword: includePasswords),
        remotePayload: remotePayload,
        remote: c.remote,
        tombstone: c.tombstone,
      ));
    }

    // 8. Pushes. Files first (revision-suffixed names never collide with
    // live data), manifest next, sidecar last as the commit.
    var nextSidecar = remote;
    if (plan.pushesAnything ||
        !remoteExists ||
        effectiveConfig.forcePushPending) {
      final devId = await deviceId();
      final devTag = devId.length >= 4 ? devId.substring(0, 4) : devId;
      final newAccounts =
          Map<int, SyncRemoteAccount>.of(remote.accounts);
      final newTombstones = Map<int, SyncTombstone>.of(remote.tombstones);

      for (final push in plan.pushes) {
        final acc = byId[push.steamId];
        if (acc == null) continue;
        final payload = payloads[push.steamId]!;
        final enc = encryptSyncPayload(passphrase, payload);
        // Device-tagged name: two devices pushing the same account at the
        // same rev must not overwrite each other's file mid-race.
        final filename = '${push.steamId}.r${push.newRev}.$devTag.maFile';
        await transport.putFile(
            filename, Uint8List.fromList(utf8.encode(enc.ciphertext)));
        newAccounts[push.steamId] = SyncRemoteAccount(
          rev: push.newRev,
          hash: localHashes[push.steamId]!,
          filename: filename,
          salt: enc.salt,
          iv: enc.iv,
        );
        newTombstones.remove(push.steamId);
        newBase[push.steamId] = SyncBaseEntry(
            rev: push.newRev, hash: localHashes[push.steamId]!);
        newSeen.remove(push.steamId);
        pushed++;
      }

      for (final t in plan.tombstonePushes) {
        newAccounts.remove(t.steamId);
        newTombstones[t.steamId] = SyncTombstone(
          rev: t.newRev,
          deletedAt: now().toUtc().toIso8601String(),
          device: devId,
        );
        newBase.remove(t.steamId);
        newSeen[t.steamId] = t.newRev;
      }

      // Mint a fresh check token when this device is committing a new
      // passphrase epoch — carrying the old token forward would lock every
      // other device out with "wrong passphrase" against the NEW phrase.
      final passkeyCheck = (remote.passkeyCheck == null ||
              effectiveConfig.passphraseEpoch > remote.passphraseEpoch)
          ? buildPasskeyCheck(passphrase)
          : remote.passkeyCheck!;
      nextSidecar = remote.copyWith(
        includePasswords: includePasswords,
        passphraseEpoch: effectiveConfig.passphraseEpoch,
        passkeyCheck: passkeyCheck,
        accounts: newAccounts,
        tombstones: newTombstones,
        devices: {
          ...remote.devices,
          devId: SyncDeviceInfo(
            name: effectiveConfig.deviceName,
            lastSyncAt: now().toUtc().toIso8601String(),
          ),
        },
      );

      if (!remoteExists) await transport.ensureRoot();

      // Manifest before sidecar: a crash in between leaves an SDA folder
      // whose manifest already matches the new files (still fully readable),
      // while the old sidecar just makes the next round re-push.
      await transport.putFile(
        kSyncManifestFilename,
        Uint8List.fromList(
            utf8.encode(buildRemoteManifest(newAccounts, passkeyCheck))),
      );

      try {
        await transport.putFile(
          kSyncSidecarFilename,
          Uint8List.fromList(utf8.encode(nextSidecar.serialize())),
          ifMatch: remoteExists ? sidecarFile?.etag : null,
          ifAbsent: !remoteExists,
        );
      } on SyncPreconditionFailed {
        return _RoundOutcome.commitRaced;
      }

      // Post-commit GC: files the new sidecar no longer references.
      final live = {for (final a in newAccounts.values) a.filename};
      for (final old in remote.accounts.values) {
        if (!live.contains(old.filename)) {
          try {
            await transport.deleteFile(old.filename);
          } catch (_) {/* orphan; the next committer retries */}
        }
      }
    }

    // 9. Bookkeeping the plan asked for without data movement.
    for (final adopt in plan.baseAdopts) {
      if (adopt.drop) {
        newBase.remove(adopt.steamId);
        newSeen.remove(adopt.steamId);
      } else if (adopt.tombstone) {
        newBase.remove(adopt.steamId);
        newSeen[adopt.steamId] = adopt.rev;
      } else {
        newBase[adopt.steamId] =
            SyncBaseEntry(rev: adopt.rev, hash: adopt.hash);
      }
    }

    await configStore
        .saveState(SyncLocalState(base: newBase, tombstonesSeen: newSeen));
    if (effectiveConfig.forcePushPending) {
      await configStore
          .saveConfig(effectiveConfig.copyWith(forcePushPending: false));
    }

    _publish(_status.copyWith(
      configured: true,
      syncing: false,
      lastSyncAt: now(),
      errorKind: SyncErrorKind.none,
      needsPassphrase: false,
      conflicts: conflicts,
      lastPushed: pushed,
      lastPulled: pulled,
    ));
    return _RoundOutcome.done;
  }

  Future<Map<String, dynamic>?> _fetchPayload(SyncTransport transport,
      SyncRemoteAccount remote, String passphrase) async {
    final file = await transport.getFile(remote.filename);
    if (file == null) return null;
    return decryptSyncPayload(
        passphrase, remote.salt, remote.iv, utf8.decode(file.bytes));
  }

  // ─── Conflict resolution ───────────────────────────────────────────────

  /// Resolves one conflict. The losing side's payload goes to the trash;
  /// then local bookkeeping is adjusted so the next round carries the
  /// winner outward (keep local) or nothing (keep remote), and a round is
  /// triggered immediately.
  Future<void> resolveConflict(int steamId, {required bool keepLocal}) async {
    final item = _status.conflicts
        .where((c) => c.steamId == steamId)
        .firstOrNull;
    if (item == null) return;
    final passphrase = await configStore.loadPassphrase();
    if (passphrase == null) return;
    final state = await configStore.loadState();
    final newBase = Map<int, SyncBaseEntry>.of(state.base);
    final newSeen = Map<int, int>.of(state.tombstonesSeen);

    if (keepLocal) {
      if (item.remotePayload != null) {
        await trash.put(
          steamId: steamId,
          accountName: item.remotePayload?['account_name'] as String?,
          payload: item.remotePayload!,
          reason: SyncTrashReason.conflictRemote,
          passphrase: passphrase,
        );
      }
      // Align the base with the remote so the local copy reads as "changed
      // on top of it" — the next round pushes rev+1 (or resurrects past the
      // tombstone).
      if (item.remote != null) {
        newBase[steamId] =
            SyncBaseEntry(rev: item.remote!.rev, hash: item.remote!.hash);
      } else if (item.tombstone != null) {
        newBase.remove(steamId);
        newSeen[steamId] = item.tombstone!.rev;
      }
      if (item.kind == SyncConflictKind.deleteEdit) {
        // "Keep local" of a local delete = the delete wins: mark the remote
        // version as seen so the next round pushes the tombstone.
        // (base already aligned above; nothing else to do)
      }
    } else {
      // Keep remote. Trash the local copy (when one exists), then apply.
      if (item.localPayload != null) {
        await trash.put(
          steamId: steamId,
          accountName: item.localPayload?['account_name'] as String?,
          payload: item.localPayload!,
          reason: SyncTrashReason.conflictLocal,
          passphrase: passphrase,
        );
      }
      if (item.kind == SyncConflictKind.editDelete) {
        // Remote deleted it; accept the deletion.
        await accounts.removeAccount(steamId);
        newBase.remove(steamId);
        newSeen[steamId] = item.tombstone!.rev;
      } else if (item.remotePayload != null && item.remote != null) {
        await accounts.applyRemote(item.remotePayload!);
        newBase[steamId] =
            SyncBaseEntry(rev: item.remote!.rev, hash: item.remote!.hash);
      }
    }

    await configStore
        .saveState(SyncLocalState(base: newBase, tombstonesSeen: newSeen));
    _publish(_status.copyWith(
      conflicts: [
        for (final c in _status.conflicts)
          if (c.steamId != steamId) c
      ],
    ));
    await syncNow();
  }

  // ─── Settings mutations ────────────────────────────────────────────────

  Future<void> setAutoSync(bool enabled) async {
    final config = await configStore.loadConfig();
    if (config == null) return;
    await configStore.saveConfig(config.copyWith(autoSync: enabled));
  }

  /// Flips whether payloads carry the account password. Marks a full
  /// re-push: the remote ciphertext must change for every account, not just
  /// the ones whose payload hash moved.
  Future<void> setSyncPasswords(bool enabled) async {
    final config = await configStore.loadConfig();
    if (config == null) return;
    await configStore.saveConfig(
        config.copyWith(syncPasswords: enabled, forcePushPending: true));
    await syncNow();
  }

  /// Accepts a re-entered passphrase after [SyncErrorKind.passphrase],
  /// verifying it against the remote before storing.
  Future<bool> providePassphrase(String passphrase) async {
    final config = await configStore.loadConfig();
    final webdavPassword = await configStore.loadWebdavPassword();
    if (config == null || webdavPassword == null) return false;
    final transport = transportFactory(config, webdavPassword);
    try {
      final sidecarFile = await transport.getFile(kSyncSidecarFilename);
      if (sidecarFile != null) {
        final remote = SyncSidecar.parse(utf8.decode(sidecarFile.bytes));
        final check = verifyPasskeyCheck(passphrase, remote.passkeyCheck);
        if (check == false) return false;
        if (check == null && remote.accounts.isNotEmpty) {
          // Older remote without a check token: test-decrypt one entry.
          final probe = remote.accounts.values.first;
          if (await _fetchPayload(transport, probe, passphrase) == null) {
            return false;
          }
        }
        await configStore.saveConfig(
            config.copyWith(passphraseEpoch: remote.passphraseEpoch));
      }
      await configStore.savePassphrase(passphrase);
      _publish(_status.copyWith(
          needsPassphrase: false, errorKind: SyncErrorKind.none));
      unawaited(syncNow());
      return true;
    } finally {
      transport.close();
    }
  }

  /// Changes the sync passphrase: bumps the epoch, re-encrypts everything.
  /// Refused while pulls or conflicts are outstanding — a passphrase change
  /// re-pushes only what this device holds, so everything must be local
  /// first or remote-only accounts would be stranded under the old key.
  Future<String?> changePassphrase(String newPassphrase) async {
    final config = await configStore.loadConfig();
    if (config == null) return 'not configured';
    await syncNow();
    if (_status.conflicts.isNotEmpty) return 'conflicts pending';
    if (_status.hasError) return 'sync not clean';
    await configStore.savePassphrase(newPassphrase);
    await configStore.saveConfig(config.copyWith(
      passphraseEpoch: config.passphraseEpoch + 1,
      forcePushPending: true,
    ));
    // The forced round re-encrypts every payload and commits the new epoch
    // plus a fresh passkey_check (see the epoch check in _attemptRound).
    await syncNow();
    return _status.hasError ? (_status.errorDetail ?? 'sync failed') : null;
  }

  /// Fetches the current remote sidecar for the read-only "view remote"
  /// screen. Null when unconfigured or the remote has no sidecar yet.
  Future<SyncSidecar?> fetchRemoteSidecar() async {
    final config = await configStore.loadConfig();
    final webdavPassword = await configStore.loadWebdavPassword();
    if (config == null || webdavPassword == null) return null;
    final transport = transportFactory(config, webdavPassword);
    try {
      final file = await transport.getFile(kSyncSidecarFilename);
      if (file == null) return null;
      return SyncSidecar.parse(utf8.decode(file.bytes));
    } finally {
      transport.close();
    }
  }

  /// Disconnects sync. [deleteRemote] additionally removes every file the
  /// sidecar references plus manifest + sidecar (the caller has already put
  /// the long-press confirmation in front of this).
  Future<void> disconnect({required bool deleteRemote}) async {
    final config = await configStore.loadConfig();
    if (config != null && deleteRemote) {
      final webdavPassword = await configStore.loadWebdavPassword();
      if (webdavPassword != null) {
        final transport = transportFactory(config, webdavPassword);
        try {
          final sidecarFile = await transport.getFile(kSyncSidecarFilename);
          if (sidecarFile != null) {
            final remote = SyncSidecar.parse(utf8.decode(sidecarFile.bytes));
            for (final a in remote.accounts.values) {
              await transport.deleteFile(a.filename);
            }
          }
          await transport.deleteFile(kSyncManifestFilename);
          await transport.deleteFile(kSyncSidecarFilename);
        } finally {
          transport.close();
        }
      }
    }
    _debounceTimer?.cancel();
    await configStore.clearAll();
    _publish(const SyncEngineStatus(configured: false));
  }
}

enum _RoundOutcome { done, commitRaced }
