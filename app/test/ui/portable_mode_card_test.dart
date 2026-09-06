import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/services/portable_library.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/portable_mode_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temp_dir.dart';

void main() {
  testWidgets('no portable switch on mobile/default provider', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PortableModeCard())),
    );
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'enable/disable both ask about migration; cancellation changes nothing',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('ava-portable-ui-');
      addTearDown(() => deleteTempDirSync(temp));
      final portable = PortableLibrary(
        MemoryStorageProvider('${temp.path}/usb/maFiles'),
      );
      final container = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(
            MemoryStorageProvider('${temp.path}/local/maFiles'),
          ),
          portableLibraryProvider.overrideWithValue(portable),
        ],
      );
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await container.read(appControllerProvider.future);
        await portable.configure('a long portable password');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: PortableModeCard()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(
          'Also copy existing local accounts to maFiles beside the app?\n\nCopies are verified and the source is kept as a backup. Accounts already in the destination are skipped. Portable accounts are not included in this computer’s WebDAV sync.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(portable.enabled, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Switch only'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(portable.enabled, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('Also copy portable accounts back to AppData?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Copy and switch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(portable.enabled, isFalse);
      expect(portable.configured, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
