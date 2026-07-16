import 'dart:io';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyTextSize', () {
    test('small leaves the ambient scaler untouched', () {
      const base = TextScaler.linear(1.2);
      expect(applyTextSize(base, AvaTextSize.small), same(base));
    });

    test('medium and large stack on top of the OS scaler', () {
      const base = TextScaler.linear(2.0);
      expect(applyTextSize(base, AvaTextSize.medium).scale(10),
          closeTo(23.0, 0.001)); // 10 * 2.0 * 1.15
      expect(applyTextSize(base, AvaTextSize.large).scale(10),
          closeTo(26.0, 0.001)); // 10 * 2.0 * 1.3
    });
  });

  group('TextSizeController', () {
    test('defaults to small', () {
      final container = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(MemoryStorageProvider()),
      ]);
      addTearDown(container.dispose);
      expect(container.read(textSizeProvider), AvaTextSize.small);
    });

    test('persists the chosen size across containers', () async {
      // SettingsStore writes app_settings.json next to the maFiles dir on
      // the real filesystem, so point the fake storage at a temp dir.
      final tmp = await Directory.systemTemp.createTemp('ava_text_size');
      addTearDown(() => tmp.delete(recursive: true));
      final storage = MemoryStorageProvider(p.join(tmp.path, 'maFiles'));

      final first = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
      ]);
      await first.read(textSizeProvider.notifier).setSize(AvaTextSize.large);
      first.dispose();

      final second = ProviderContainer(overrides: [
        storageProvider.overrideWithValue(storage),
      ]);
      addTearDown(second.dispose);
      second.read(textSizeProvider); // trigger the async load in build()
      for (var i = 0;
          i < 50 && second.read(textSizeProvider) != AvaTextSize.large;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(second.read(textSizeProvider), AvaTextSize.large);
    });
  });
}
