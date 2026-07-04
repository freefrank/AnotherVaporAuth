import 'dart:convert';
import 'dart:typed_data';

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
  });
}
