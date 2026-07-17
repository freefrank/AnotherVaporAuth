// file_selector_platform_interface is a transitive dep of file_selector,
// pinned by its own version constraint — same fake-the-platform pattern as
// path_provider/share_plus below.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/import_helper.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// Points `getTemporaryDirectory()` at a real, disposable directory so the
/// export flow's file I/O runs against the filesystem instead of a missing
/// platform channel.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempDir);
  final Directory tempDir;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
}

/// Records whatever path was shared (if any) and hands back a canned
/// [ShareResult] without touching a real platform channel. Optionally throws,
/// to simulate a share failure/cancellation.
class _FakeShare extends SharePlatform {
  _FakeShare({this.throwOnShare = false});
  final bool throwOnShare;
  String? sharedPath;
  bool existedDuringShare = false;

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    sharedPath = files.single.path;
    existedDuringShare = File(sharedPath!).existsSync();
    if (throwOnShare) {
      throw Exception('share failed');
    }
    return const ShareResult('', ShareResultStatus.success);
  }
}

/// Hands importMaFileFlow's file picker an in-memory maFile — XFile.fromData
/// keeps the bytes off disk, so the whole import flow runs in the fake-async
/// test zone without runAsync gymnastics.
class _FakeFileSelector extends FileSelectorPlatform {
  _FakeFileSelector(this.contents, {this.name = 'import.maFile'});
  final String contents;
  final String name;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      XFile.fromData(Uint8List.fromList(utf8.encode(contents)), name: name);
}

SteamGuardAccount _account() =>
    SteamGuardAccount(accountName: 'tester', sharedSecret: 'secret');

/// Pumps a bare screen, then drives exportMaFileFlow's confirm dialog and
/// awaits the export to completion.
///
/// exportMaFileFlow itself is invoked from *inside* [WidgetTester.runAsync]
/// so its whole async chain — including the real dart:io calls that happen
/// after the dialog's `await` — runs in the real-async zone; a plain
/// `pumpAndSettle()` never advances real (non-fake) Futures, so without this
/// the export would hang forever waiting on `getTemporaryDirectory()` /
/// `File.writeAsString()`. The dialog itself still needs the ordinary
/// fake-async pump/tap machinery to build and be tapped, which is why the
/// pump/tap below happen on the outer (non-runAsync) tester.
Future<void> _runExportFlow(
  WidgetTester tester,
  SteamGuardAccount account,
) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold(body: SizedBox());
        },
      ),
    ),
  );

  final resultFuture = tester.runAsync(() => exportMaFileFlow(ctx, account));
  await tester.pump(); // let the confirm dialog build
  final l = AppLocalizations.of(ctx);
  await tester.tap(find.text(l.commonExport));
  await tester.pump(); // dispatch the confirm tap
  await resultFuture; // let the real file write + share + cleanup finish
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ava_export_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'exportMaFileFlow deletes the plaintext maFile after a successful share',
    (tester) async {
      final fakeShare = _FakeShare();
      SharePlatform.instance = fakeShare;

      await _runExportFlow(tester, _account());

      expect(fakeShare.sharedPath, isNotNull);
      // The file must still exist while share_plus is reading it...
      expect(fakeShare.existedDuringShare, isTrue);
      // ...but must be gone once the share has completed.
      expect(File(fakeShare.sharedPath!).existsSync(), isFalse);
    },
  );

  testWidgets(
    'exportMaFileFlow still deletes the plaintext maFile if sharing throws',
    (tester) async {
      final fakeShare = _FakeShare(throwOnShare: true);
      SharePlatform.instance = fakeShare;

      await _runExportFlow(tester, _account());

      expect(fakeShare.sharedPath, isNotNull);
      expect(File(fakeShare.sharedPath!).existsSync(), isFalse);
    },
  );

  testWidgets('importing a duplicate steamid prompts; cancel writes nothing', (
    tester,
  ) async {
    const steamId = 76561198000000123;
    final original = {
      'account_name': 'tester',
      'shared_secret': 'c2VjcmV0',
      'revocation_code': 'R11111',
      'Session': {'SteamID': steamId},
    };
    final incoming = Map<String, dynamic>.from(original)
      ..['revocation_code'] = 'R22222';
    FileSelectorPlatform.instance = _FakeFileSelector(
      jsonEncode(incoming),
      name: '$steamId.maFile',
    );

    final storage = MemoryStorageProvider();
    late BuildContext ctx;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          timeAlignerProvider.overrideWithValue(() async {}),
        ],
        child: MaterialApp(
          // The overwrite dialog styles its destructive action off AvaTokens.
          theme: buildAvaTheme(AvaThemeVariant.neon),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Consumer(
            builder: (context, ref, _) {
              ctx = context;
              widgetRef = ref;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );

    // Bootstrap (real settings-file IO) and seed the original account
    // through the real import API, so the collision is genuine.
    await tester.runAsync(() async {
      final container = ProviderScope.containerOf(ctx);
      await container.read(appControllerProvider.future);
      await container
          .read(appControllerProvider.notifier)
          .importMaFile(jsonEncode(original));
    });
    expect(storage.files['$steamId.maFile'], contains('R11111'));

    // The picked file is in-memory (XFile.fromData), so the whole flow runs
    // on fake-async pumps.
    final flowDone = importMaFileFlow(ctx, widgetRef);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final l = AppLocalizations.of(ctx);
    expect(find.text(l.importDuplicateTitle), findsOneWidget);
    // The stored account decoded (storedReadable), so the dialog may promise
    // the kept fields — the unreadable copy must not appear here.
    expect(find.text(l.importDuplicateBody('tester')), findsOneWidget);

    await tester.tap(find.text(l.commonCancel));
    await tester.pump();
    await flowDone;

    // Cancel = silent no-write: stored data untouched, no success snackbar.
    expect(storage.files['$steamId.maFile'], contains('R11111'));
    expect(storage.files['$steamId.maFile'], isNot(contains('R22222')));
    expect(find.text(l.importSuccess), findsNothing);
  });

  group('sessionActivatedSilently', () {
    test('no tokens in the imported maFile needs a sign-in prompt', () {
      expect(
        sessionActivatedSilently(hasTokens: false, refreshSucceeded: false),
        isFalse,
      );
    });

    test('tokens present but the refresh call failed needs a prompt', () {
      expect(
        sessionActivatedSilently(hasTokens: true, refreshSucceeded: false),
        isFalse,
      );
    });

    test('tokens present and refreshed successfully is silent', () {
      expect(
        sessionActivatedSilently(hasTokens: true, refreshSucceeded: true),
        isTrue,
      );
    });
  });
}
