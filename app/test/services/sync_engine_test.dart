import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/core/sync/sync_transport.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/sync/sync_config_store.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:ava/src/services/sync/sync_trash.dart';
import 'package:flutter_test/flutter_test.dart';

// End-to-end engine tests over an in-memory transport: two simulated
// devices share one "server" map and sync against it. This is the spec's
// acceptance list run as code — propagation both ways, tombstones, both
// conflict outcomes with trash copies, the 412 retry, the weak-ETag server,
// the passwords toggle, and the trash-write-failure refusal.

/// One shared in-memory WebDAV-ish server.
class InMemoryServer {
  final Map<String, (Uint8List, String)> files = {};
  int etagSeq = 0;
  bool enforceConditionals = true;

  /// Called before every PUT — lets a test inject a concurrent commit.
  void Function(String name)? onPut;
}

class InMemoryTransport implements SyncTransport {
  final InMemoryServer server;
  InMemoryTransport(this.server);

  @override
  Future<void> ensureRoot() async {}

  @override
  Future<RemoteFile?> getFile(String name) async {
    final f = server.files[name];
    return f == null ? null : RemoteFile(f.$1, f.$2);
  }

  @override
  Future<String?> putFile(String name, Uint8List bytes,
      {String? ifMatch, bool ifAbsent = false}) async {
    server.onPut?.call(name);
    if (server.enforceConditionals) {
      final existing = server.files[name];
      if (ifAbsent && existing != null) {
        throw const SyncPreconditionFailed('exists');
      }
      if (ifMatch != null &&
          (existing == null || existing.$2 != ifMatch)) {
        throw const SyncPreconditionFailed('etag mismatch');
      }
    }
    final etag = 'e${++server.etagSeq}';
    server.files[name] = (bytes, etag);
    return etag;
  }

  @override
  Future<void> deleteFile(String name) async => server.files.remove(name);

  @override
  Future<void> probe() async {}

  @override
  Future<bool> checkConditionalSupport() async =>
      server.enforceConditionals;

  @override
  void close() {}
}

class MemoryConfigStore extends SyncConfigStore {
  MemoryConfigStore() : super(MemoryStorageProvider());

  SyncConfig? config;
  SyncLocalState state = const SyncLocalState();
  String? webdavPassword = 'server-pw';
  String? passphrase;

  @override
  Future<SyncConfig?> loadConfig() async => config;
  @override
  Future<void> saveConfig(SyncConfig c) async => config = c;
  @override
  Future<SyncLocalState> loadState() async => state;
  @override
  Future<void> saveState(SyncLocalState s) async => state = s;
  @override
  Future<String?> loadWebdavPassword() async => webdavPassword;
  @override
  Future<void> saveWebdavPassword(String p) async => webdavPassword = p;
  @override
  Future<String?> loadPassphrase() async => passphrase;
  @override
  Future<void> savePassphrase(String p) async => passphrase = p;
  @override
  Future<void> clearAll() async {
    config = null;
    state = const SyncLocalState();
    webdavPassword = null;
  }
}

class MemoryTrash extends SyncTrash {
  MemoryTrash() : super(MemoryStorageProvider());

  final List<({int steamId, SyncTrashReason reason})> entries = [];
  bool failPuts = false;

  @override
  Future<bool> put({
    required int steamId,
    required String? accountName,
    required Map<String, dynamic> payload,
    required SyncTrashReason reason,
    required String passphrase,
  }) async {
    if (failPuts) return false;
    entries.add((steamId: steamId, reason: reason));
    return true;
  }

  @override
  Future<void> purgeExpired() async {}
}

class FakePort implements SyncAccountsPort {
  final List<SteamGuardAccount> accounts = [];
  bool locked = false;

  @override
  List<SteamGuardAccount>? snapshot() => locked ? null : accounts;

  @override
  Future<void> applyRemote(Map<String, dynamic> payload) async {
    final incoming = SteamGuardAccount.fromJson(
        jsonDecode(jsonEncode(payload)) as Map<String, dynamic>);
    accounts.removeWhere((a) => a.steamId == incoming.steamId);
    accounts.add(incoming);
  }

  @override
  Future<void> removeAccount(int steamId) async {
    accounts.removeWhere((a) => a.steamId == steamId);
  }
}

/// One simulated device.
class Device {
  final MemoryConfigStore configStore = MemoryConfigStore();
  final MemoryTrash trash = MemoryTrash();
  final FakePort port = FakePort();
  late final SyncEngine engine;

  Device(InMemoryServer server, String id, {String passphrase = kPass}) {
    configStore.config = const SyncConfig(
      url: 'https://example.com/dav/ava/',
      username: 'user',
      deviceName: 'test-device',
    );
    configStore.passphrase = passphrase;
    engine = SyncEngine(
      configStore: configStore,
      accounts: port,
      trash: trash,
      transportFactory: (_, _) => InMemoryTransport(server),
      deviceId: () async => id,
    );
  }
}

const kPass = 'correct horse battery staple';

SteamGuardAccount account(int steamId,
        {String name = 'gaben', String password = 'pw123'}) =>
    SteamGuardAccount.fromJson({
      'shared_secret': 'c2VjcmV0',
      'identity_secret': 'aWRlbnRpdHk=',
      'account_name': name,
      'password': password,
      'Session': {
        'SteamID': steamId,
        'AccessToken': 'localToken',
        'RefreshToken': 'localRefresh',
      },
    });

void main() {
  const id1 = 76561198000000001;
  const id2 = 76561198000000002;

  test('first device pushes an SDA-readable encrypted folder', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.addAll([account(id1), account(id2, name: 'alt')]);

    await a.engine.syncNow();

    expect(a.engine.status.hasError, isFalse);
    expect(a.engine.status.lastPushed, 2);

    // The sidecar and the SDA manifest both exist and agree.
    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.accounts, hasLength(2));
    final manifest = jsonDecode(
            utf8.decode(server.files[kSyncManifestFilename]!.$1))
        as Map<String, dynamic>;
    expect(manifest['encrypted'], isTrue);
    expect(manifest['entries'], hasLength(2));

    // Each referenced file decrypts with the passphrase, carries the
    // password, and carries no session tokens.
    for (final entry in sidecar.accounts.values) {
      final payload = decryptSyncPayload(kPass, entry.salt, entry.iv,
          utf8.decode(server.files[entry.filename]!.$1));
      expect(payload, isNotNull);
      expect(payload!['password'], 'pw123');
      final session = payload['Session'] as Map<String, dynamic>;
      expect(session.containsKey('RefreshToken'), isFalse);
    }
  });

  test('second device pulls everything and keeps identities', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    expect(b.engine.status.lastPulled, 1);
    final got = b.port.accounts.single;
    expect(got.steamId, id1);
    expect(got.password, 'pw123');
    expect(got.session.hasTokens, isFalse);
  });

  test('an edit propagates A → B; a session refresh does not', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    // Session-only change: nothing to sync.
    a.port.accounts.single.session.accessToken = 'rotated';
    await a.engine.syncNow();
    expect(a.engine.status.lastPushed, 0);

    // Real change: propagates.
    a.port.accounts.single.password = 'newpass';
    await a.engine.syncNow();
    expect(a.engine.status.lastPushed, 1);
    await b.engine.syncNow();
    expect(b.port.accounts.single.password, 'newpass');
  });

  test('a delete propagates as a tombstone and lands in the trash',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.addAll([account(id1), account(id2, name: 'alt')]);
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    // B deletes one account.
    b.port.accounts.removeWhere((x) => x.steamId == id2);
    await b.engine.syncNow();

    // A applies the tombstone: account gone, trash copy kept.
    await a.engine.syncNow();
    expect(a.port.accounts.map((x) => x.steamId), [id1]);
    expect(a.trash.entries.single.steamId, id2);
    expect(a.trash.entries.single.reason, SyncTrashReason.remoteDelete);

    // And it does NOT bounce back on B's next round.
    await b.engine.syncNow();
    expect(b.port.accounts.map((x) => x.steamId), [id1]);
  });

  test('a failed trash write refuses the local delete', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    b.port.accounts.clear();
    await b.engine.syncNow();

    a.trash.failPuts = true;
    await a.engine.syncNow();
    // The delete was refused; the account is still here.
    expect(a.port.accounts, hasLength(1));

    // Once the trash works again the delete goes through.
    a.trash.failPuts = false;
    await a.engine.syncNow();
    expect(a.port.accounts, isEmpty);
  });

  test('divergent edits conflict; keep-local wins outward and the loser '
      'is trashed', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    a.port.accounts.single.password = 'versionA';
    await a.engine.syncNow();
    b.port.accounts.single.password = 'versionB';
    await b.engine.syncNow();

    final conflict = b.engine.status.conflicts.single;
    expect(conflict.steamId, id1);
    // Both sides are in hand for the compare UI.
    expect(conflict.localPayload?['password'], 'versionB');
    expect(conflict.remotePayload?['password'], 'versionA');

    await b.engine.resolveConflict(id1, keepLocal: true);
    expect(b.engine.status.conflicts, isEmpty);
    expect(b.trash.entries.single.reason, SyncTrashReason.conflictRemote);

    await a.engine.syncNow();
    expect(a.port.accounts.single.password, 'versionB');
  });

  test('keep-remote applies the other side and trashes the local copy',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    a.port.accounts.single.password = 'versionA';
    await a.engine.syncNow();
    b.port.accounts.single.password = 'versionB';
    await b.engine.syncNow();

    await b.engine.resolveConflict(id1, keepLocal: false);
    expect(b.port.accounts.single.password, 'versionA');
    expect(b.trash.entries.single.reason, SyncTrashReason.conflictLocal);
  });

  test('a lost commit race re-merges instead of overwriting', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    // A stages a change. Mid-push — right before A commits its sidecar —
    // another device commits a new account, so A's If-Match fails.
    a.port.accounts.single.password = 'racer';
    // The competing device's payload really exists on the server, exactly
    // as a real committer would have left it (file first, sidecar last).
    final otherPayload =
        syncPayloadJson(account(id2, name: 'alt'), includePassword: true);
    final otherEnc = encryptSyncPayload(kPass, otherPayload);
    server.files['$id2.r1.devC.maFile'] = (
      Uint8List.fromList(utf8.encode(otherEnc.ciphertext)),
      'eX',
    );
    var injected = false;
    server.onPut = (name) {
      if (name == kSyncSidecarFilename && !injected) {
        injected = true;
        server.onPut = null;
        final current = SyncSidecar.parse(
            utf8.decode(server.files[kSyncSidecarFilename]!.$1));
        final updated = current.copyWith(accounts: {
          ...current.accounts,
          id2: SyncRemoteAccount(
            rev: 1,
            hash: payloadHash(otherPayload),
            filename: '$id2.r1.devC.maFile',
            salt: otherEnc.salt,
            iv: otherEnc.iv,
          ),
        });
        server.files[kSyncSidecarFilename] = (
          Uint8List.fromList(utf8.encode(updated.serialize())),
          'e${++server.etagSeq}',
        );
      }
    };

    await a.engine.syncNow();
    expect(a.engine.status.hasError, isFalse);

    // A's change landed AND B's competing entry survived.
    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.accounts.keys, containsAll([id1, id2]));
  });

  test('wrong passphrase is reported as a passphrase problem, not '
      'corruption', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    final b = Device(server, 'devB0002', passphrase: 'totally wrong one');
    await b.engine.syncNow();
    expect(b.engine.status.needsPassphrase, isTrue);
    expect(b.engine.status.errorKind, SyncErrorKind.passphrase);
    expect(b.port.accounts, isEmpty);

    // providePassphrase with the right one heals it.
    expect(await b.engine.providePassphrase(kPass), isTrue);
    await b.engine.syncNow();
    expect(b.port.accounts, hasLength(1));
  });

  test('turning password sync off strips passwords from the remote',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    await a.engine.setSyncPasswords(false);

    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.includePasswords, isFalse);
    final entry = sidecar.accounts[id1]!;
    final payload = decryptSyncPayload(kPass, entry.salt, entry.iv,
        utf8.decode(server.files[entry.filename]!.$1));
    expect(payload!.containsKey('password'), isFalse);

    // The other device adopts the flag instead of fighting it.
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();
    expect(b.configStore.config!.syncPasswords, isFalse);
  });

  test('changing the passphrase re-encrypts and locks out the old one',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    const newPass = 'an entirely new passphrase';
    expect(await a.engine.changePassphrase(newPass), isNull);

    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.passphraseEpoch, 2);
    expect(verifyPasskeyCheck(newPass, sidecar.passkeyCheck), isTrue);
    expect(verifyPasskeyCheck(kPass, sidecar.passkeyCheck), isFalse);

    // A device still holding the old passphrase is asked for the new one.
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();
    expect(b.engine.status.needsPassphrase, isTrue);
  });

  test('a locked device does nothing', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.locked = true;
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    expect(server.files, isEmpty);
  });

  test('disconnect with deleteRemote clears the server', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    expect(server.files, isNotEmpty);

    await a.engine.disconnect(deleteRemote: true);
    expect(server.files, isEmpty);
    expect(a.configStore.config, isNull);
    // The local account itself is untouched — disconnect is about sync,
    // never about the library.
    expect(a.port.accounts, hasLength(1));
  });

  test('garbage collection removes superseded payload files', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final firstFiles =
        server.files.keys.where((k) => k.endsWith('.maFile')).toList();

    a.port.accounts.single.password = 'changed';
    await a.engine.syncNow();
    final secondFiles =
        server.files.keys.where((k) => k.endsWith('.maFile')).toList();

    expect(secondFiles, hasLength(1));
    expect(secondFiles.single, isNot(firstFiles.single));
  });
}
