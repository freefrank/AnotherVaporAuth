import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

/// Stamped by CI: --dart-define=AVA_VERSION=x.y.z
const appVersion = String.fromEnvironment('AVA_VERSION', defaultValue: 'dev');

const _regKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\AVA';

/// Install / uninstall backend. On non-Windows platforms it runs in dry-run
/// mode (extracts only, skips shortcuts/registry) so the UI can be developed
/// and smoke-tested on Linux.
class InstallEngine {
  static bool get isDryRun => !Platform.isWindows;

  static String get defaultInstallDir => Platform.isWindows
      ? p.join(
          Platform.environment['LOCALAPPDATA'] ?? r'C:\', 'Programs', 'AVA')
      : p.join(Platform.environment['HOME'] ?? '/tmp', 'ava-install-dryrun');

  static Future<void> install({
    required String dir,
    required bool desktopShortcut,
    required void Function(String line) log,
    required void Function(double p01) progress,
  }) async {
    log('loading payload');
    final data = await rootBundle.load('assets/payload.zip');
    final zip = ZipDecoder().decodeBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final files = zip.files.where((f) => f.isFile).toList();
    // The committed asset is a tiny placeholder; a real payload has the full
    // Flutter bundle. Refuse to "install" the placeholder.
    if (files.length < 5) {
      throw StateError('payload is a build-time placeholder — '
          'this binary was packaged without the real app');
    }
    final total = files.fold<int>(0, (s, f) => s + f.size);
    var done = 0;
    await Directory(dir).create(recursive: true);
    for (final f in files) {
      final out = File(p.join(dir, f.name));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>);
      done += f.size;
      log(f.name);
      progress(done / total * 0.85);
      // Tiny stagger so the log is readable instead of one instant blur.
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    if (isDryRun) {
      log('dry-run: skipping uninstaller / shortcuts / registry');
      progress(1.0);
      return;
    }
    log('writing uninstaller');
    final uninstaller = p.join(dir, 'uninstall.exe');
    await File(Platform.resolvedExecutable).copy(uninstaller);
    progress(0.90);
    log('creating shortcuts');
    await _shortcut('Programs', p.join(dir, 'ava.exe'), dir);
    if (desktopShortcut) {
      await _shortcut('Desktop', p.join(dir, 'ava.exe'), dir);
    }
    progress(0.95);
    log('registering uninstall entry');
    await _registerUninstall(dir, uninstaller, total ~/ 1024);
    progress(1.0);
    log('install complete');
  }

  /// Sanity check before uninstalling: only ever delete a folder that
  /// actually looks like an AVA install (never e.g. a Downloads folder the
  /// setup exe was launched from with a stray --uninstall flag).
  static bool looksLikeInstallDir(String dir) =>
      File(p.join(dir, 'ava.exe')).existsSync() &&
      Directory(p.join(dir, 'data')).existsSync();

  static String get selfDir => p.dirname(Platform.resolvedExecutable);

  // ---- two-stage uninstall ----
  // The uninstaller can't clean the install dir while running from it: it
  // can't delete its own exe, and the Enigma box overlays its virtual files
  // (data/, flutter_windows.dll, …) onto the real dir, so deletes on the
  // shadowed names fail. Classic solution (same as Inno Setup): copy self to
  // %TEMP%, relaunch from there, and let the staged copy do the real work.
  // The handover uses a sidecar file, not argv — command lines have proven
  // unreliable across the Enigma boundary.

  static const _stageExe = 'ava_uninstall_stage.exe';
  static String get _tempDir =>
      Platform.environment['TEMP'] ?? r'C:\Windows\Temp';
  static String get _markerPath => p.join(_tempDir, 'ava_uninstall_job.txt');

  /// True when this process is the staged copy running from %TEMP%.
  static bool get isStaged =>
      p.basename(Platform.resolvedExecutable).toLowerCase() == _stageExe;

  /// Auto flag recorded by the first stage for the staged copy.
  static bool get stagedAuto {
    try {
      return File(_markerPath).readAsLinesSync().contains('auto');
    } catch (_) {
      return false;
    }
  }

  /// Stage 1, runs from the install dir: removes shortcuts + registry, then
  /// hands over to a copy of itself in %TEMP% and returns so the caller can
  /// exit immediately.
  static Future<void> uninstallPrepare({
    required void Function(String line) log,
    required void Function(double p01) progress,
  }) async {
    final dir = selfDir;
    if (!looksLikeInstallDir(dir)) {
      throw StateError('$dir does not look like an AVA install — aborting');
    }
    log('closing running instances');
    await Process.run(
        'taskkill', ['/im', 'ava.exe', '/f', '/fi', 'STATUS eq RUNNING']);
    progress(0.3);
    log('removing shortcuts');
    await _ps('''
\$ws = New-Object -ComObject WScript.Shell
foreach (\$sf in @('Programs','Desktop')) {
  \$lnk = Join-Path \$ws.SpecialFolders(\$sf) 'AVA.lnk'
  if (Test-Path \$lnk) { Remove-Item \$lnk -Force }
}''');
    progress(0.6);
    log('removing registry entry');
    await Process.run('reg', ['delete', _regKey, '/f']);
    progress(0.8);
    log('handing over to cleanup stage');
    final stage = p.join(_tempDir, _stageExe);
    await File(Platform.resolvedExecutable).copy(stage);
    File(_markerPath).writeAsStringSync(
        [dir, if (_autoHandover) 'auto'].join('\n'));
    await Process.start(stage, const [], mode: ProcessStartMode.detached);
    progress(1.0);
  }

  /// Set by main() so the staged copy knows to run unattended.
  static bool _autoHandover = false;
  static set autoHandover(bool v) => _autoHandover = v;

  /// Stage 2, runs from %TEMP%: deletes the whole install dir (retrying
  /// while stage 1 shuts down), then schedules its own removal via RunOnce.
  static Future<void> uninstallExecute({
    required void Function(String line) log,
    required void Function(double p01) progress,
  }) async {
    final lines = File(_markerPath).readAsLinesSync();
    final dir = lines.first.trim();
    if (!looksLikeInstallDir(dir)) {
      throw StateError('$dir does not look like an AVA install — aborting');
    }
    log('removing $dir');
    var deleted = false;
    for (var i = 0; i < 30 && !deleted; i++) {
      try {
        await Directory(dir).delete(recursive: true);
        deleted = true;
      } catch (_) {
        // Stage 1 (uninstall.exe) may still be exiting and holding its lock.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        progress(0.1 + 0.7 * (i / 30));
      }
    }
    if (!deleted) {
      throw StateError('could not remove $dir (files still in use?)');
    }
    progress(0.9);
    log('scheduling stage cleanup');
    File(_markerPath).delete().ignore();
    // This staged exe can't delete itself either; RunOnce sweeps it at the
    // next logon (reg.exe from inside the box is proven reliable).
    await Process.run('reg', [
      'add', r'HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce',
      '/v', 'AVAUninstallStageCleanup',
      '/d', 'cmd.exe /c del /f /q "${p.join(_tempDir, _stageExe)}"', '/f',
    ]);
    progress(1.0);
    log('uninstalled — this window can be closed');
  }

  static Future<void> _shortcut(
      String specialFolder, String target, String workDir) async {
    await _ps('''
\$ws = New-Object -ComObject WScript.Shell
\$lnk = \$ws.CreateShortcut((Join-Path \$ws.SpecialFolders('$specialFolder') 'AVA.lnk'))
\$lnk.TargetPath = '${_q(target)}'
\$lnk.WorkingDirectory = '${_q(workDir)}'
\$lnk.IconLocation = '${_q(target)},0'
\$lnk.Save()''');
  }

  static Future<void> _registerUninstall(
      String dir, String uninstaller, int sizeKb) async {
    Future<void> add(String name, String value,
        {bool dword = false}) async {
      final r = await Process.run('reg', [
        'add', _regKey, '/v', name,
        if (dword) ...['/t', 'REG_DWORD'],
        '/d', value, '/f',
      ]);
      if (r.exitCode != 0) {
        throw StateError('reg add $name failed: ${r.stderr}');
      }
    }

    await add('DisplayName', 'AVA');
    await add('DisplayVersion', appVersion);
    await add('Publisher', 'dotSlash');
    await add('InstallLocation', dir);
    await add('DisplayIcon', p.join(dir, 'ava.exe'));
    await add('UninstallString', '"$uninstaller" --uninstall');
    await add('QuietUninstallString', '"$uninstaller" --uninstall --auto');
    await add('URLInfoAbout', 'https://github.com/freefrank/AnotherVaporAuth');
    await add('NoModify', '1', dword: true);
    await add('NoRepair', '1', dword: true);
    await add('EstimatedSize', '$sizeKb', dword: true);
  }

  static Future<void> _ps(String script) async {
    final r = await Process.run('powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script]);
    if (r.exitCode != 0) {
      throw StateError('powershell failed: ${r.stderr}');
    }
  }

  /// Escapes a path for embedding in a single-quoted PowerShell string.
  static String _q(String s) => s.replaceAll("'", "''");
}
