import 'dart:convert';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Storage whose deleteFile always throws, to prove reset can't brick the
/// vault even when file cleanup fails.
class DeleteFailingStorage extends MemoryStorageProvider {
  @override
  Future<void> deleteFile(String filename) async {
    throw Exception('delete failed');
  }
}

void main() {
  test('performVaultReset leaves an unlocked empty store even if delete fails',
      () async {
    final storage = DeleteFailingStorage();
    // Seed a vault manifest + a payload, as if a real (now undecryptable)
    // vault were present.
    storage.files['manifest.json'] =
        jsonEncode(Manifest(vault: true, encrypted: true, entries: []).toJson());
    storage.files['111.maFile'] = 'opaque-vault-blob';

    final order = <String>[];
    await performVaultReset(
      storage: storage,
      clearKeys: () async => order.add('clearKeys'),
      disableBiometric: () async => order.add('disableBiometric'),
    );

    // The manifest was committed clean BEFORE the keys were dropped.
    final m = Manifest.fromJson(
        jsonDecode(storage.files['manifest.json']!) as Map<String, dynamic>);
    expect(m.vault, isFalse);
    expect(m.encrypted, isFalse);
    expect(m.entries, isEmpty);
    expect(order, ['clearKeys', 'disableBiometric']);

    // Bootstrap now yields an unlocked, empty store — never a locked vault.
    final reloaded = await AccountStore.load(storage);
    expect(reloaded.isVault, isFalse);
    expect(reloaded.encrypted, isFalse);
    expect(await reloaded.getAllAccounts(), isEmpty);
  });
}
