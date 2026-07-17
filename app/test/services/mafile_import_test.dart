import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// A valid 20-byte Steam shared secret, base64 (what generateCode expects).
final _secret = base64.encode(Uint8List.fromList(List.generate(20, (i) => i)));

String _maFile(Map<String, dynamic> extra) => jsonEncode({
      'shared_secret': _secret,
      'identity_secret': _secret,
      'revocation_code': 'R12345',
      'account_name': 'tester',
      ...extra,
    });

void main() {
  group('maFile import compatibility', () {
    test('a Session-less maFile imports as a code-only account', () async {
      final store = AccountStore(MemoryStorageProvider());
      final acc = await store.importMaFileContents(
          _maFile({'Session': null}), null,
          sourceName: 'tester.maFile');
      // No SteamID anywhere → stable negative synthetic id, never a real one.
      expect(acc.steamId, lessThan(0));
      expect(acc.generateCode(1751000000).length, 5); // codes work offline
      expect((await store.getAllAccounts()).length, 1);
    });

    test('re-importing the same code-only maFile dedups', () async {
      final store = AccountStore(MemoryStorageProvider());
      await store.importMaFileContents(_maFile({'Session': null}), null);
      await store.importMaFileContents(_maFile({'Session': null}), null);
      expect((await store.getAllAccounts()).length, 1);
    });

    test('recovers a decimal SteamID alias (Steam++ steam64)', () async {
      final store = AccountStore(MemoryStorageProvider());
      final acc = await store.importMaFileContents(
          _maFile({'steam64': '76561198000000003'}), null);
      expect(acc.steamId, 76561198000000003);
    });

    test('recovers a base64-encoded SteamID', () async {
      const id = 76561198000000123;
      final bytes = Uint8List(8);
      ByteData.sublistView(bytes).setUint64(0, id, Endian.little);
      final store = AccountStore(MemoryStorageProvider());
      final acc = await store.importMaFileContents(
          _maFile({'steamid': base64.encode(bytes)}), null);
      expect(acc.steamId, id);
    });

    test('recovers a SteamID from the filename', () async {
      final store = AccountStore(MemoryStorageProvider());
      final acc = await store.importMaFileContents(
          _maFile({'Session': null}), null,
          sourceName: '76561198000000005.maFile');
      expect(acc.steamId, 76561198000000005);
    });

    test('rejects a maFile with neither SteamID nor a secret', () async {
      final store = AccountStore(MemoryStorageProvider());
      final bad = jsonEncode({'account_name': 'x', 'Session': null});
      expect(store.importMaFileContents(bad, null),
          throwsA(isA<MaFileImportException>()));
    });

    test('synthetic id is stable across calls and negative', () {
      final json =
          jsonDecode(_maFile({'Session': null})) as Map<String, dynamic>;
      final a = SteamGuardAccount.fromJson(json);
      final b = SteamGuardAccount.fromJson(json);
      expect(AccountStore.syntheticSteamId(a),
          AccountStore.syntheticSteamId(b));
      expect(AccountStore.syntheticSteamId(a), lessThan(0));
    });

    test('parseMaFileContents resolves the effective id without writing',
        () async {
      final store = AccountStore(MemoryStorageProvider());
      final acc = store
          .parseMaFileContents(_maFile({'steam64': '76561198000000003'}));
      expect(acc.steamId, 76561198000000003);
      expect(store.entries, isEmpty);
      expect(await store.getAllAccounts(), isEmpty);
    });

    test('parseMaFileContents throws on no SteamID and no secret', () {
      final store = AccountStore(MemoryStorageProvider());
      final bad = jsonEncode({'account_name': 'x', 'Session': null});
      expect(() => store.parseMaFileContents(bad),
          throwsA(isA<MaFileImportException>()));
    });

    test('re-import with the same steamid keeps manifest position', () async {
      final store = AccountStore(MemoryStorageProvider());
      await store.importMaFileContents(
          _maFile({'steam64': '76561198000000001'}), null);
      await store.importMaFileContents(
          _maFile({'steam64': '76561198000000002'}), null);
      await store.importMaFileContents(
          _maFile({'steam64': '76561198000000001', 'revocation_code': 'R99999'}),
          null);
      expect(store.entries.map((e) => e.steamId).toList(),
          [76561198000000001, 76561198000000002]);
      final updated = (await store.getAllAccounts())
          .firstWhere((a) => a.steamId == 76561198000000001);
      expect(updated.revocationCode, 'R99999');
    });
  });

  group('import overwrite merge policy', () {
    SteamGuardAccount existingWithEverything() => SteamGuardAccount(
          sharedSecret: 'old-secret',
          revocationCode: 'R-OLD',
          accountName: 'tester',
          avatarUrl: 'https://a/av.jpg',
          personaName: 'Persona',
          password: 'pw',
          session:
              SessionData(steamId: 42, accessToken: 'tok', refreshToken: 'r'),
        );

    test('preserves enrichment and live session when the file lacks them', () {
      final incoming = SteamGuardAccount(
        sharedSecret: _secret,
        revocationCode: 'R-NEW',
        accountName: 'tester',
        session: SessionData(steamId: 42),
      );
      mergeImportedAccount(incoming, existingWithEverything());
      expect(incoming.avatarUrl, 'https://a/av.jpg');
      expect(incoming.personaName, 'Persona');
      expect(incoming.password, 'pw');
      expect(incoming.session.accessToken, 'tok'); // stored session survives
      // Authenticator material always comes from the file.
      expect(incoming.sharedSecret, _secret);
      expect(incoming.revocationCode, 'R-NEW');
    });

    test('an incoming session with tokens wins over the stored one', () {
      final incoming = SteamGuardAccount(
        sharedSecret: _secret,
        session: SessionData(steamId: 42, accessToken: 'new-tok'),
      );
      mergeImportedAccount(incoming, existingWithEverything());
      expect(incoming.session.accessToken, 'new-tok');
      expect(incoming.session.refreshToken, isNull);
    });

    test('importMaFileContents(mergeExisting:) applies the merge', () async {
      final store = AccountStore(MemoryStorageProvider());
      const id = 76561198000000009;
      final existing = await store.importMaFileContents(
          _maFile({
            'persona_name': 'Persona',
            'Session': {'SteamID': id, 'AccessToken': 'tok'},
          }),
          null);
      expect(existing.session.accessToken, 'tok');

      // Token-less re-import of the same account (e.g. a stale backup).
      await store.importMaFileContents(_maFile({'steam64': '$id'}), null,
          mergeExisting: existing);

      final accounts = await store.getAllAccounts();
      expect(accounts.single.steamId, id);
      expect(accounts.single.personaName, 'Persona');
      expect(accounts.single.session.accessToken, 'tok');
    });
  });
}
