import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// A valid 20-byte Steam shared secret, base64 (what generateCode expects).
final _secret = base64.encode(Uint8List.fromList(List.generate(20, (i) => i)));

String _maFile({int? steamId, bool withTokens = false}) => jsonEncode({
      'shared_secret': _secret,
      'identity_secret': _secret,
      'revocation_code': 'R12345',
      'account_name': 'tester',
      'Session': {
        'SteamID': steamId ?? 76561198000000123,
        if (withTokens) 'AccessToken': 'access-token',
        if (withTokens) 'RefreshToken': 'refresh-token',
      },
    });

void main() {
  group('AppController.importMaFile', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(MemoryStorageProvider()),
        // Avoid a real network call from the post-accept bootstrap hook.
        timeAlignerProvider.overrideWithValue(() async {}),
      ]);
      addTearDown(container.dispose);
    });

    test('returns the imported account, already reflected in state',
        () async {
      await container.read(appControllerProvider.future); // wait for bootstrap

      final account = await container
          .read(appControllerProvider.notifier)
          .importMaFile(_maFile(steamId: 76561198000000321));

      expect(account.steamId, 76561198000000321);
      expect(account.accountName, 'tester');
      final state = container.read(appControllerProvider).value!;
      expect(state.accounts.map((a) => a.steamId), contains(account.steamId));
    });

    test(
        'imported account with no session tokens reports hasTokens=false '
        '(the signal import_helper uses to decide whether to prompt)',
        () async {
      await container.read(appControllerProvider.future);

      final account = await container
          .read(appControllerProvider.notifier)
          .importMaFile(_maFile(withTokens: false));

      expect(account.session.hasTokens, isFalse);
    });
  });
}
