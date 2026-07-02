import 'dart:convert';

import 'package:ava/src/core/crypto/vault_crypto.dart';
import 'package:ava/src/services/vault_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Key names mirrored from VaultKeyStore (private there by design).
const kRecord = 'ava.vault.pinWrap';
const kLegacyWrapped = 'ava.vault.wrappedDek';
const kLegacySalt = 'ava.vault.pinSalt';
const kLegacyIterations = 'ava.vault.pinKdfIter';

void main() {
  late Map<String, String> data;
  late VaultKeyStore store;

  setUp(() {
    data = <String, String>{};
    // The test platform keeps a reference to [data], so seeding and
    // asserting on it observes the real storage state.
    FlutterSecureStorage.setMockInitialValues(data);
    store = VaultKeyStore(store: const FlutterSecureStorage());
  });

  test('storePinWrap writes one atomic record and round-trips', () async {
    final dek = VaultCrypto.generateDek();
    await store.storePinWrap('123456', dek);

    expect(data.keys, [kRecord]); // single key — atomic updates
    final rec = jsonDecode(data[kRecord]!) as Map<String, dynamic>;
    expect(rec['iter'], VaultCrypto.pinKdfIterations);

    expect(await store.exists, isTrue);
    expect(await store.unwrapWithPin('123456'), equals(dek));
    expect(await store.unwrapWithPin('654321'), isNull);
  });

  test('legacy split-key layout unwraps and migrates to the record', () async {
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.randomSaltB64();
    data[kLegacySalt] = salt;
    data[kLegacyWrapped] =
        VaultCrypto.wrapDek('123456', salt, dek, iterations: 1000);
    data[kLegacyIterations] = '1000';

    expect(await store.exists, isTrue);
    expect(await store.unwrapWithPin('123456'), equals(dek));

    // Migrated: record present at the current KDF cost, legacy keys gone.
    expect(data.keys, [kRecord]);
    final rec = jsonDecode(data[kRecord]!) as Map<String, dynamic>;
    expect(rec['iter'], VaultCrypto.pinKdfIterations);
    expect(await store.unwrapWithPin('123456'), equals(dek));
  });

  test('pre-iteration-key legacy layout defaults to 100k rounds', () async {
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.randomSaltB64();
    data[kLegacySalt] = salt;
    data[kLegacyWrapped] =
        VaultCrypto.wrapDek('123456', salt, dek, iterations: 100000);

    expect(await store.unwrapWithPin('123456'), equals(dek));
    expect(data.keys, [kRecord]);
  });

  test('wrong PIN on a legacy layout does not migrate or destroy it',
      () async {
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.randomSaltB64();
    data[kLegacySalt] = salt;
    data[kLegacyWrapped] =
        VaultCrypto.wrapDek('123456', salt, dek, iterations: 1000);
    data[kLegacyIterations] = '1000';

    expect(await store.unwrapWithPin('000000'), isNull);
    expect(data.containsKey(kLegacyWrapped), isTrue);
    expect(data.containsKey(kRecord), isFalse);
    expect(await store.unwrapWithPin('123456'), equals(dek));
  });

  test('a record at an outdated KDF cost is re-wrapped on unlock', () async {
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.randomSaltB64();
    data[kRecord] = jsonEncode({
      'v': 1,
      'salt': salt,
      'iter': 1000,
      'wrap': VaultCrypto.wrapDek('123456', salt, dek, iterations: 1000),
    });

    expect(await store.unwrapWithPin('123456'), equals(dek));
    final rec = jsonDecode(data[kRecord]!) as Map<String, dynamic>;
    expect(rec['iter'], VaultCrypto.pinKdfIterations);
  });

  test('a corrupt record falls back to intact legacy keys and self-heals',
      () async {
    // The lockout scenario: a migration write is torn mid-way, leaving an
    // unparseable record next to the still-valid legacy wrap.
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.randomSaltB64();
    data[kRecord] = '{"v":1,"salt":"tor'; // truncated JSON
    data[kLegacySalt] = salt;
    data[kLegacyWrapped] =
        VaultCrypto.wrapDek('123456', salt, dek, iterations: 1000);
    data[kLegacyIterations] = '1000';

    expect(await store.unwrapWithPin('123456'), equals(dek));

    // Healed: a fresh valid record, legacy keys cleaned up.
    expect(data.keys, [kRecord]);
    final rec = jsonDecode(data[kRecord]!) as Map<String, dynamic>;
    expect(rec['iter'], VaultCrypto.pinKdfIterations);
    expect(await store.unwrapWithPin('123456'), equals(dek));
  });

  test('a corrupt record without a legacy fallback returns null, not a throw',
      () async {
    data[kRecord] = 'not json at all';
    expect(await store.unwrapWithPin('123456'), isNull);
    // Wrong-typed fields fail the same way as unparseable JSON.
    data[kRecord] = jsonEncode({'v': 1, 'salt': 42, 'iter': 'x', 'wrap': []});
    expect(await store.unwrapWithPin('123456'), isNull);
  });

  test('rewrapPin changes the PIN, keeps the DEK', () async {
    final dek = VaultCrypto.generateDek();
    await store.storePinWrap('123456', dek);

    expect(await store.rewrapPin('999999', '654321'), isFalse);
    expect(await store.rewrapPin('123456', '654321'), isTrue);
    expect(await store.unwrapWithPin('123456'), isNull);
    expect(await store.unwrapWithPin('654321'), equals(dek));
  });

  test('clear removes both layouts', () async {
    await store.storePinWrap('123456', VaultCrypto.generateDek());
    data[kLegacyWrapped] = 'stale';
    data[kLegacySalt] = 'stale';
    await store.clear();
    expect(data, isEmpty);
    expect(await store.exists, isFalse);
    expect(await store.unwrapWithPin('123456'), isNull);
  });
}
