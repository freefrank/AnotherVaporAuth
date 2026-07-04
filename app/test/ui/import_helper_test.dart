import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/ui/import_helper.dart';
import 'package:flutter/material.dart';
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

SteamGuardAccount _account() => SteamGuardAccount(
      accountName: 'tester',
      sharedSecret: 'secret',
    );

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
  });

  testWidgets(
      'exportMaFileFlow still deletes the plaintext maFile if sharing throws',
      (tester) async {
    final fakeShare = _FakeShare(throwOnShare: true);
    SharePlatform.instance = fakeShare;

    await _runExportFlow(tester, _account());

    expect(fakeShare.sharedPath, isNotNull);
    expect(File(fakeShare.sharedPath!).existsSync(), isFalse);
  });
}
