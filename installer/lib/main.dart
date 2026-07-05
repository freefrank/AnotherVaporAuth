import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'engine.dart';
import 'fx.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final uninstall = args.contains('--uninstall') ||
      p.basename(Platform.resolvedExecutable).toLowerCase() ==
          'uninstall.exe';
  final auto = args.contains('--auto');
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(760, 460),
    center: true,
    title: 'AVA Setup',
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(InstallerApp(uninstall: uninstall, auto: auto));
}

class InstallerApp extends StatelessWidget {
  const InstallerApp(
      {super.key, required this.uninstall, required this.auto});
  final bool uninstall;
  final bool auto;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Fx.bg,
            fontFamily: Fx.font),
        home: InstallerScreen(uninstall: uninstall, auto: auto),
      );
}

enum Phase { ready, working, done, error }

class InstallerScreen extends StatefulWidget {
  const InstallerScreen(
      {super.key, required this.uninstall, required this.auto});
  final bool uninstall;
  final bool auto;

  @override
  State<InstallerScreen> createState() => _InstallerScreenState();
}

class _InstallerScreenState extends State<InstallerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fx =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  late final AnimationController _marquee = AnimationController(
      vsync: this, duration: const Duration(seconds: 22))
    ..repeat();
  final _path = TextEditingController(text: InstallEngine.defaultInstallDir);
  final _scroll = ScrollController();
  final _logs = <String>[];
  var _phase = Phase.ready;
  var _progress = 0.0;
  var _desktopShortcut = true;
  String _error = '';

  static const _greetz = ' *** AVA // ANOTHERVAPORAUTH *** OPEN SOURCE (MIT)'
      ' *** STEAM AUTH ON YOUR OWN TERMS *** NO TELEMETRY - NO BACKEND'
      ' *** GITHUB.COM/FREEFRANK/ANOTHERVAPORAUTH *** GREETZ TO THE BETA CREW'
      ' *** ';

  @override
  void initState() {
    super.initState();
    if (widget.auto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _fx.dispose();
    _marquee.dispose();
    _path.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _log(String line) {
    stdout.writeln(line);
    setState(() => _logs.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _phase = Phase.working;
      _progress = 0;
      _logs.clear();
    });
    try {
      if (widget.uninstall) {
        await InstallEngine.uninstall(
            log: _log, progress: (v) => setState(() => _progress = v));
      } else {
        await InstallEngine.install(
          dir: _path.text.trim(),
          desktopShortcut: _desktopShortcut,
          log: _log,
          progress: (v) => setState(() => _progress = v),
        );
      }
      setState(() => _phase = Phase.done);
      if (widget.auto) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        exit(0);
      }
    } catch (e) {
      stderr.writeln('ERROR: $e');
      setState(() {
        _phase = Phase.error;
        _error = '$e';
      });
      if (widget.auto) exit(1);
    }
  }

  Future<void> _launchAndExit() async {
    await Process.start(p.join(_path.text.trim(), 'ava.exe'), const [],
        workingDirectory: _path.text.trim(),
        mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fx,
        builder: (context, _) => Stack(children: [
          Positioned.fill(
              child: CustomPaint(painter: ScanlinePainter(_fx.value))),
          Column(children: [
            _titleBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 4, 30, 10),
                child: _body(),
              ),
            ),
            AnimatedBuilder(
              animation: _marquee,
              builder: (context, _) => Marquee(_greetz, t: _marquee.value),
            ),
            const SizedBox(height: 6),
          ]),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                  painter: FramePainter(
                      0.5 + 0.5 * (1 - (_fx.value * 2 - 1).abs()))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _titleBar() {
    return SizedBox(
      height: 34,
      child: Row(children: [
        Expanded(
          child: DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    widget.uninstall ? 'AVA.UNINSTALL.EXE' : 'AVA.SETUP.EXE',
                    style: Fx.text(11, color: Fx.dim)),
              ),
            ),
          ),
        ),
        _winBtn('—', () => windowManager.minimize()),
        _winBtn('✕', () => exit(0), hoverColor: Fx.magenta),
      ]),
    );
  }

  Widget _winBtn(String label, VoidCallback onTap,
      {Color hoverColor = Fx.cyan}) {
    return HoverBox(
      hoverColor: hoverColor,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 34,
        child: Center(child: Text(label, style: Fx.text(13, color: Fx.dim))),
      ),
    );
  }

  Widget _body() {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GlitchTitle('AVA', t: _fx.value),
        const SizedBox(width: 6),
        BlinkCursor(t: _fx.value),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              widget.uninstall
                  ? 'UNINSTALL v$appVersion'
                  : 'SETUP v$appVersion',
              style: Fx.text(13, color: Fx.dim)),
        ),
      ],
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 16),
      Expanded(child: _phaseView()),
    ]);
  }

  Widget _phaseView() {
    switch (_phase) {
      case Phase.ready:
        return widget.uninstall ? _readyUninstall() : _readyInstall();
      case Phase.working:
        return _working();
      case Phase.done:
        return _done();
      case Phase.error:
        return _errorView();
    }
  }

  Widget _readyInstall() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('TARGET DIR', style: Fx.text(12, color: Fx.dim)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: Fx.panel, border: Border.all(color: Fx.line, width: 2)),
        child: TextField(
          controller: _path,
          style: Fx.text(13, color: Fx.cyan),
          cursorColor: Fx.magenta,
          decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
      const SizedBox(height: 14),
      _check('CREATE DESKTOP SHORTCUT', _desktopShortcut,
          (v) => setState(() => _desktopShortcut = v)),
      const Spacer(),
      Row(children: [
        Text(InstallEngine.isDryRun ? '// DRY-RUN (non-windows)' : '',
            style: Fx.text(11, color: Fx.dim)),
        const Spacer(),
        PixelButton('EXIT', color: Fx.dim, onTap: () => exit(0)),
        const SizedBox(width: 12),
        PixelButton('INSTALL', onTap: _start),
      ]),
    ]);
  }

  Widget _readyUninstall() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('REMOVE AVA FROM THIS MACHINE?',
          style: Fx.text(16, color: Fx.magenta)),
      const SizedBox(height: 10),
      Text(InstallEngine.selfDir, style: Fx.text(12, color: Fx.dim)),
      const SizedBox(height: 10),
      Text('YOUR ACCOUNT DATA (MAFILES) IS NOT DELETED.',
          style: Fx.text(12, color: Fx.dim)),
      const Spacer(),
      Row(children: [
        const Spacer(),
        PixelButton('EXIT', color: Fx.dim, onTap: () => exit(0)),
        const SizedBox(width: 12),
        PixelButton('UNINSTALL', color: Fx.magenta, onTap: _start),
      ]),
    ]);
  }

  Widget _working() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: SegmentBar(_progress)),
        const SizedBox(width: 10),
        SizedBox(
            width: 52,
            child: Text('${(_progress * 100).round()}%',
                textAlign: TextAlign.right,
                style: Fx.text(14, color: Fx.cyan))),
      ]),
      const SizedBox(height: 12),
      Expanded(child: _terminal()),
    ]);
  }

  Widget _terminal() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFF040710),
          border: Border.all(color: Fx.line, width: 2)),
      child: ListView.builder(
        controller: _scroll,
        itemCount: _logs.length,
        itemBuilder: (context, i) => Text('> ${_logs[i]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Fx.text(12,
                color: i == _logs.length - 1
                    ? Fx.cyan
                    : Fx.cyan.withValues(alpha: 0.55))),
      ),
    );
  }

  Widget _done() {
    final uninstall = widget.uninstall;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(uninstall ? 'UNINSTALL COMPLETE' : 'INSTALL COMPLETE',
          style: Fx.text(18, color: Fx.green, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (!uninstall)
        Text(_path.text.trim(), style: Fx.text(12, color: Fx.dim)),
      const SizedBox(height: 10),
      Expanded(child: _terminal()),
      const SizedBox(height: 12),
      Row(children: [
        const Spacer(),
        PixelButton('EXIT', color: Fx.dim, onTap: () => exit(0)),
        if (!uninstall && !InstallEngine.isDryRun) ...[
          const SizedBox(width: 12),
          PixelButton('LAUNCH AVA', color: Fx.green, onTap: _launchAndExit),
        ],
      ]),
    ]);
  }

  Widget _errorView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('ERROR', style: Fx.text(18, color: Fx.magenta)),
      const SizedBox(height: 8),
      Text(_error, maxLines: 3, style: Fx.text(12, color: Fx.dim)),
      const SizedBox(height: 10),
      Expanded(child: _terminal()),
      const SizedBox(height: 12),
      Row(children: [
        const Spacer(),
        PixelButton('EXIT', color: Fx.magenta, onTap: () => exit(1)),
      ]),
    ]);
  }

  Widget _check(String label, bool value, void Function(bool) onChanged) {
    return HoverBox(
      onTap: () => onChanged(!value),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 16,
          height: 16,
          decoration:
              BoxDecoration(border: Border.all(color: Fx.cyan, width: 2)),
          child: value
              ? Center(child: Container(width: 6, height: 6, color: Fx.cyan))
              : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: Fx.text(12, color: Fx.cyan)),
      ]),
    );
  }
}

class HoverBox extends StatefulWidget {
  const HoverBox(
      {super.key, required this.child, required this.onTap, this.hoverColor});
  final Widget child;
  final VoidCallback onTap;
  final Color? hoverColor;

  @override
  State<HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<HoverBox> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ColoredBox(
          color: _hover
              ? (widget.hoverColor ?? Fx.cyan).withValues(alpha: 0.15)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
