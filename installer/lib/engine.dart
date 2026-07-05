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

  static Future<void> uninstall({
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
    progress(0.2);
    log('removing shortcuts');
    await _ps('''
\$ws = New-Object -ComObject WScript.Shell
foreach (\$sf in @('Programs','Desktop')) {
  \$lnk = Join-Path \$ws.SpecialFolders(\$sf) 'AVA.lnk'
  if (Test-Path \$lnk) { Remove-Item \$lnk -Force }
}''');
    progress(0.5);
    log('removing registry entry');
    await Process.run('reg', ['delete', _regKey, '/f']);
    progress(0.8);
    log('scheduling folder removal');
    // This exe lives inside the folder, so it can't delete it while running.
    // A plain detached child doesn't survive either: the Enigma box tears
    // down / cripples children spawned from inside it on exit. So the
    // cleanup script goes to %TEMP% and is launched via WMI
    // Win32_Process.Create — that process is parented to the WMI service,
    // outside our process tree, and reliably outlives the uninstaller.
    final script = p.join(
        Platform.environment['TEMP'] ?? r'C:\Windows\Temp',
        'ava_uninstall_cleanup.ps1');
    File(script).writeAsStringSync('''
for (\$i = 0; \$i -lt 30; \$i++) {
  Start-Sleep 1
  try { Remove-Item -LiteralPath '${_q(dir)}' -Recurse -Force -ErrorAction Stop; break } catch {}
}
Remove-Item -LiteralPath \$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
''');
    await _ps("Invoke-CimMethod -ClassName Win32_Process -MethodName Create "
        "-Arguments @{ CommandLine = 'powershell -NoProfile -WindowStyle "
        "Hidden -ExecutionPolicy Bypass -File \"${_q(script)}\"' } "
        '| Out-Null');
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
