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

  /// The outer executable the user actually launched — setup.exe,
  /// uninstall.exe, or the staged copy in %TEMP%.
  ///
  /// The NSIS wrapper (tool/setup.nsi) unpacks this app into its own scratch
  /// directory and runs it from there, so [Platform.resolvedExecutable]
  /// points at that scratch copy, not at the file on the user's disk. Five
  /// things depend on the outer path and would all be wrong without this
  /// seam: which mode to start in, where the install lives, whether this is
  /// the staged copy, and the two places that reproduce the program by
  /// copying its own image. The wrapper passes it as `--self=<path>`;
  /// [Platform.resolvedExecutable] remains the answer when the app is run
  /// unpacked (developing on Linux, `flutter run`).
  static String selfImage = Platform.resolvedExecutable;

  /// Reads `--self=<path>` out of [args]. Call once, before anything reads
  /// [selfImage].
  static void adoptSelfImage(List<String> args) {
    const flag = '--self=';
    for (final a in args) {
      if (a.startsWith(flag) && a.length > flag.length) {
        selfImage = a.substring(flag.length);
        return;
      }
    }
  }

  static String get defaultInstallDir => Platform.isWindows
      ? p.join(
          Platform.environment['LOCALAPPDATA'] ?? r'C:\', 'Programs', 'AVA')
      : p.join(Platform.environment['HOME'] ?? '/tmp', 'ava-install-dryrun');

  /// Name of the file listing everything [install] wrote, one relative path
  /// per line. Uninstall deletes exactly this list — never the directory
  /// wholesale.
  static const manifestName = 'ava-install.manifest';

  /// Why [dir] must not be used as an install target, or null if it is fine.
  ///
  /// The install directory is a free-text field, and uninstall used to delete
  /// whatever it pointed at as long as `ava.exe` and `data\` were present. A
  /// user who typed (or browsed to) their Documents folder therefore got their
  /// Documents folder deleted on uninstall — unrecoverable, and entirely
  /// plausible since many installers append their own subfolder to whatever
  /// you pick and this one does not.
  ///
  /// Returns a message meant for the UI, not a log.
  static String? validateInstallDir(String dir) {
    final raw = dir.trim();
    if (raw.isEmpty) return 'Choose an install folder.';
    if (!p.isAbsolute(raw)) return 'Enter a full path, not a relative one.';

    final norm = p.normalize(raw);
    // A volume root ("C:\", "/") has no parent to fall back to and holds
    // everything on the drive.
    if (p.equals(norm, p.rootPrefix(norm))) {
      return 'Refusing to install to a drive root. Pick a subfolder.';
    }

    for (final protected in _protectedDirs()) {
      if (p.equals(norm, protected)) {
        return 'Refusing to install to ${p.basename(protected)} — '
            'uninstall would remove the whole folder. Pick a subfolder.';
      }
    }

    // An existing directory with unrelated content in it: installing here
    // would mix our files into someone else's folder, and even a manifest
    // uninstall leaves the user wondering what happened.
    final existing = Directory(norm);
    if (existing.existsSync()) {
      final entries = existing.listSync();
      final ours = File(p.join(norm, manifestName)).existsSync() ||
          looksLikeInstallDir(norm);
      if (entries.isNotEmpty && !ours) {
        return 'That folder already contains other files. '
            'Pick an empty or new folder.';
      }
    }
    return null;
  }

  /// Directories that must never *be* the install target (a subfolder of them
  /// is fine). Missing environment variables simply drop out.
  static List<String> _protectedDirs() {
    final env = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'];
    return <String>[
      for (final v in [
        env['USERPROFILE'],
        env['HOME'],
        env['SystemRoot'],
        env['windir'],
        env['ProgramFiles'],
        env['ProgramFiles(x86)'],
        env['ProgramData'],
        env['LOCALAPPDATA'],
        env['APPDATA'],
        env['PUBLIC'],
      ])
        if (v != null && v.trim().isNotEmpty) p.normalize(v),
      if (home != null)
        for (final leaf in const [
          'Desktop',
          'Documents',
          'Downloads',
          'Pictures',
          'Music',
          'Videos',
          'OneDrive',
        ])
          p.normalize(p.join(home, leaf)),
    ];
  }

  /// Rejects a zip entry whose name would escape [dir] — absolute paths, `..`
  /// segments, or a drive/UNC prefix. The payload is ours, but a tampered
  /// installer binary is exactly the case worth surviving.
  static String? resolveEntry(String dir, String name) {
    if (name.isEmpty) return null;
    if (p.isAbsolute(name) || name.contains('\\\\') || name.contains(':')) {
      return null;
    }
    final target = p.normalize(p.join(dir, name));
    final root = '${p.normalize(dir)}${p.separator}';
    return p.isWithin(p.normalize(dir), target) || target.startsWith(root)
        ? target
        : null;
  }

  static Future<void> install({
    required String dir,
    required bool desktopShortcut,
    required void Function(String line) log,
    required void Function(double p01) progress,
  }) async {
    final bad = validateInstallDir(dir);
    if (bad != null) throw StateError(bad);
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
    // Everything we create, relative to `dir` — the uninstaller deletes this
    // list and nothing else.
    final written = <String>[];
    for (final f in files) {
      final target = resolveEntry(dir, f.name);
      if (target == null) {
        throw StateError('payload entry escapes the install folder: ${f.name}');
      }
      final out = File(target);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>);
      written.add(p.relative(target, from: dir));
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
    await File(selfImage).copy(uninstaller);
    written.add('uninstall.exe');
    // Written last and listing itself, so uninstall can clean up completely.
    written.add(manifestName);
    await File(p.join(dir, manifestName)).writeAsString(written.join('\n'));
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

  /// Removes exactly what [install] recorded in [manifestName], then prunes
  /// the directories that are left empty, and finally the install folder
  /// itself — only if nothing else remains in it.
  ///
  /// Anything the user put in the folder survives. The previous behaviour was
  /// `Directory(dir).delete(recursive: true)` guarded only by "does ava.exe
  /// and data\ exist", which turns any folder someone installed into — their
  /// Documents, say — into collateral damage.
  ///
  /// Falls back to the old wholesale delete **only** when there is no
  /// manifest, i.e. the install predates this change. That fallback keeps the
  /// existing guard and is the one path that can still over-delete; it exists
  /// so upgrades from an older install can still be uninstalled at all.
  static Future<void> removeInstalled(
    String dir, {
    required void Function(String line) log,
  }) async {
    final manifest = File(p.join(dir, manifestName));
    if (!manifest.existsSync()) {
      log('no manifest (pre-1.0 install) — removing the folder wholesale');
      if (!looksLikeInstallDir(dir)) {
        throw StateError('$dir does not look like an AVA install — aborting');
      }
      await Directory(dir).delete(recursive: true);
      return;
    }

    final entries = (await manifest.readAsLines())
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final dirs = <String>{};
    for (final rel in entries) {
      // A tampered manifest must not reach outside the install folder.
      final target = resolveEntry(dir, rel);
      if (target == null) {
        log('skipping out-of-tree manifest entry: $rel');
        continue;
      }
      final f = File(target);
      if (f.existsSync()) await f.delete();
      // Every ancestor up to the install root, not just the immediate
      // parent. A Flutter install has levels that hold only directories —
      // data\flutter_assets\packages is one — and those were never
      // considered, so the whole empty skeleton outlived the uninstall and
      // kept the install folder itself from being removed.
      for (var d = p.dirname(target); p.isWithin(dir, d); d = p.dirname(d)) {
        dirs.add(d);
      }
    }
    // Deepest first, so a directory whose children were just removed is
    // considered after them.
    final ordered = dirs.toList()
      ..sort((a, b) => b.split(p.separator).length - a.split(p.separator).length);
    for (final d in ordered) {
      final directory = Directory(d);
      if (!directory.existsSync()) continue;
      if (directory.listSync().isEmpty && p.isWithin(dir, d)) {
        await directory.delete();
      }
    }
    final root = Directory(dir);
    if (root.existsSync()) {
      if (root.listSync().isEmpty) {
        await root.delete();
      } else {
        log('left ${root.listSync().length} file(s) that were not ours');
      }
    }
  }

  /// Sanity check before uninstalling: only ever delete a folder that
  /// actually looks like an AVA install (never e.g. a Downloads folder the
  /// setup exe was launched from with a stray --uninstall flag).
  static bool looksLikeInstallDir(String dir) =>
      File(p.join(dir, 'ava.exe')).existsSync() &&
      Directory(p.join(dir, 'data')).existsSync();

  static String get selfDir => p.dirname(selfImage);

  // ---- two-stage uninstall ----
  // The uninstaller can't clean the install dir while running from it:
  // uninstall.exe is the running image and Windows will not let it delete
  // itself. Classic solution (same as Inno Setup): copy self to %TEMP%,
  // relaunch from there, and let the staged copy do the real work.
  //
  // The handover uses a sidecar file rather than argv. That began as a
  // workaround for the Enigma boundary mangling command lines; it stays
  // because the staged copy is re-entered through the NSIS wrapper, which
  // owns its own argument line, and one channel we control end to end is
  // easier to reason about than two.

  static const _stageExe = 'ava_uninstall_stage.exe';
  static String get _tempDir =>
      Platform.environment['TEMP'] ?? r'C:\Windows\Temp';
  static String get _markerPath => p.join(_tempDir, 'ava_uninstall_job.txt');

  /// True when this process is the staged copy running from %TEMP%.
  static bool get isStaged => p.basename(selfImage).toLowerCase() == _stageExe;

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
    await File(selfImage).copy(stage);
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
        await removeInstalled(dir, log: log);
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
