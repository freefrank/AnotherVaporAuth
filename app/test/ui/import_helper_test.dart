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
import 'package:ava/src/ui/home_screen.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import '../support/temp_dir.dart';

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

  /// The containing directory's permission bits *while the share is running* —
  /// after it, the export flow has already removed the directory, so a stat
  /// from the test body would read 0 and assert nothing.
  int dirModeDuringShare = -1;

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
    dirModeDuringShare = File(sharedPath!).parent.statSync().mode & 0x1FF;
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

class _FakeMultiSelector extends FileSelectorPlatform {
  _FakeMultiSelector(this.files);
  final Map<String, String> files;

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => [
    for (final entry in files.entries)
      XFile.fromData(
        Uint8List.fromList(utf8.encode(entry.value)),
        name: entry.key,
        path: entry.key,
      ),
  ];
}

/// Answers the export's Save-as dialog with a fixed destination, or with
/// cancellation. Records whether it was asked at all.
class _FakeSaveLocation extends FileSelectorPlatform {
  _FakeSaveLocation(this.destination);

  /// null = the user cancelled the dialog.
  final String? destination;
  String? suggestedNameSeen;
  var asked = false;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    asked = true;
    suggestedNameSeen = options.suggestedName;
    return destination == null ? null : FileSaveLocation(destination!);
  }
}

/// Lets the success SnackBar appear and then retire.
///
/// _runExportFlow deliberately never pumps at the end — the share path shows
/// nothing. The Save-as path does, and a SnackBar arms a 4-second dismissal
/// Timer; leaving it pending hangs the test at teardown rather than failing it.
Future<void> _settleSnackBar(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
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
    // These tests run on Linux, which the export treats as desktop. Force the
    // share path so the guarantees below are exercised at all; the Save-as
    // path has its own group.
    exportUsesSaveDialog = () => false;
  });

  tearDown(() async {
    exportUsesSaveDialog = () =>
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    deleteTempDirSync(tempDir);
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

  testWidgets(
    'the plaintext maFile lives in a private, unguessable directory',
    (tester) async {
      // It used to be written straight into the shared temp dir as
      // "$accountName.maFile" — a path another local user could predict, read
      // during the share window, or pre-plant a symlink at. The directory,
      // not the file mode, is what protects it: a umask-derived 0644 file is
      // still unreachable inside a 0700 directory.
      final fakeShare = _FakeShare();
      SharePlatform.instance = fakeShare;

      await _runExportFlow(tester, _account());

      final shared = File(fakeShare.sharedPath!);
      final parent = shared.parent;
      expect(
        parent.path,
        isNot(tempDir.path),
        reason: 'must not sit directly in the shared temp dir',
      );
      // p.basename, not split(Platform.pathSeparator): the export dir is
      // joined with '/', which dart:io accepts on Windows but a '\'-only
      // split does not see.
      final name = p.basename(parent.path);
      expect(name, startsWith('export-'));
      // 16 random hex chars — enough that nothing can pre-exist at the path.
      expect(
        RegExp(r'^export-[0-9a-f]{16}$').hasMatch(name),
        isTrue,
        reason: 'directory name was "$name"',
      );
      if (!Platform.isWindows) {
        expect(
          fakeShare.dirModeDuringShare,
          0x1C0, // 0700
          reason:
              'directory mode was '
              '${fakeShare.dirModeDuringShare.toRadixString(8)}',
        );
      }
      // And the whole directory goes away with the file.
      expect(parent.existsSync(), isFalse);
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

  testWidgets(
    'batch import without manifest stores new accounts and keeps duplicates',
    (tester) async {
      final storage = MemoryStorageProvider(tempDir.path);
      final container = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(storage),
          timeAlignerProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);
      String payload(int id, String code) => jsonEncode({
        'account_name': 'user$id',
        'shared_secret': 'c2VjcmV0',
        'revocation_code': code,
        'Session': {'SteamID': id},
      });
      await tester.runAsync(() async {
        await container.read(appControllerProvider.future);
        await container.read(settingsStoreProvider).saveBackupReminderShown();
        await container
            .read(appControllerProvider.notifier)
            .importMaFile(payload(76561198000000123, 'OLD'));
      });
      FileSelectorPlatform.instance = _FakeMultiSelector({
        'old.maFile': payload(76561198000000123, 'REPLACEMENT'),
        'new.maFile': payload(76561198000000124, 'NEW'),
        'broken.maFile': 'bad data',
      });
      late BuildContext ctx;
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      await tester.runAsync(() => importSdaBundleFlow(ctx, widgetRef));
      await tester.pump();
      expect(container.read(appControllerProvider).value!.accounts.length, 2);
      expect(storage.files['76561198000000123.maFile'], contains('OLD'));
      expect(
        storage.files['76561198000000123.maFile'],
        isNot(contains('REPLACEMENT')),
      );
      expect(storage.files['76561198000000124.maFile'], contains('NEW'));
      expect(find.textContaining('manifest.json'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [390.0, 900.0]) {
    testWidgets(
      'account search expands, selects the actual matching account and clears ($width)',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer(
          overrides: [
            storageProvider.overrideWithValue(
              MemoryStorageProvider(tempDir.path),
            ),
            timeAlignerProvider.overrideWithValue(() async {}),
          ],
        );
        addTearDown(container.dispose);
        await tester.runAsync(() async {
          await container.read(appControllerProvider.future);
          await container.read(settingsStoreProvider).saveTutorialSeen();
          for (var i = 0; i < 25; i++) {
            await container
                .read(appControllerProvider.notifier)
                .importMaFile(
                  jsonEncode({
                    'account_name': i == 24 ? 'TargetUser' : 'user$i',
                    'shared_secret': 'c2VjcmV0',
                    'Session': {'SteamID': 76561198000000100 + i},
                  }),
                );
          }
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildAvaTheme(AvaThemeVariant.neon),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'targetuser');
        await tester.pump();
        expect(find.text('TargetUser'), findsOneWidget);
        await tester.tap(find.text('TargetUser'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('TargetUser'), findsNWidgets(2));
        await tester.enterText(find.byType(TextField), 'not-present');
        await tester.pump();
        expect(find.text('No matching accounts'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.search_off));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(TextField), findsNothing);
        expect(find.text('user0'), findsOneWidget);
        expect(find.text('TargetUser'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

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

  group('export on desktop', () {
    // The bug this group exists for: desktop used the share sheet, and on
    // Windows the receiving app took the *file name* as a line of text. The
    // user got a string where they asked for a maFile.
    setUp(() {
      exportUsesSaveDialog = () => true;
      SharePlatform.instance = _FakeShare();
    });

    testWidgets('writes the maFile to the path the user chose', (tester) async {
      final dest = '${tempDir.path}/picked/tester.maFile';
      // createSync, not create: a real dart:io Future never completes in
      // the fake-async zone a widget test runs in — it just hangs.
      Directory('${tempDir.path}/picked').createSync(recursive: true);
      final picker = _FakeSaveLocation(dest);
      FileSelectorPlatform.instance = picker;

      await _runExportFlow(tester, _account());
      await _settleSnackBar(tester);

      expect(picker.asked, isTrue);
      expect(picker.suggestedNameSeen, 'tester.maFile');
      final written = File(dest);
      expect(written.existsSync(), isTrue, reason: 'the export must land here');
      // Real content, not a placeholder or a path masquerading as one.
      final decoded =
          jsonDecode(written.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['shared_secret'], 'secret');
      expect(decoded['account_name'], 'tester');
    });

    testWidgets('never shares — that is what produced a string', (
      tester,
    ) async {
      final share = _FakeShare();
      SharePlatform.instance = share;
      FileSelectorPlatform.instance = _FakeSaveLocation(
        '${tempDir.path}/tester.maFile',
      );

      await _runExportFlow(tester, _account());
      await _settleSnackBar(tester);

      expect(share.sharedPath, isNull);
    });

    testWidgets('leaves no plaintext behind in the temp dir', (tester) async {
      // The share path needs a temp copy and deletes it afterwards. This one
      // should never create it: the secrets go straight to the destination.
      FileSelectorPlatform.instance = _FakeSaveLocation(
        '${tempDir.path}/tester.maFile',
      );

      await _runExportFlow(tester, _account());
      await _settleSnackBar(tester);

      final strays = tempDir.listSync().whereType<Directory>().where(
        (d) => d.path.contains('export-'),
      );
      expect(strays, isEmpty);
    });

    testWidgets('cancelling writes nothing at all', (tester) async {
      final picker = _FakeSaveLocation(null); // user pressed Cancel
      FileSelectorPlatform.instance = picker;

      await _runExportFlow(tester, _account());

      expect(picker.asked, isTrue);
      expect(
        tempDir.listSync(),
        isEmpty,
        reason: 'a cancelled export must not leave secrets anywhere',
      );
    });
  });
}
