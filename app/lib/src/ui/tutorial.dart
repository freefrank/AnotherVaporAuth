import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../l10n/app_localizations.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import 'widgets/sda_panel.dart';

/// First-run gesture tutorial: a themed coach-mark overlay that walks through
/// the home screen's hidden gestures (tap-to-copy, swipe panes, long-press
/// market, pull-to-refresh). Pushed as a transparent route over the home
/// screen; swipe steps drive the first account row's [SlidableController] so
/// the real UI demonstrates itself. Touch platforms only — desktop gets a
/// right-click context menu instead.
Future<void> showGestureTutorial(
  BuildContext context, {
  required GlobalKey codeKey,
  required GlobalKey firstRowKey,
  SlidableController? slidable,
}) {
  // A dialog route (not a PageRoute): the ambient layers only pause for
  // full-screen page pushes, so the home backdrop keeps animating inside the
  // spotlight. The transparent Material supplies the DefaultTextStyle and
  // ink plumbing that a bare route lacks.
  return Navigator.of(context).push(RawDialogRoute<void>(
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => Material(
      type: MaterialType.transparency,
      child: _GestureTutorial(
        codeKey: codeKey,
        firstRowKey: firstRowKey,
        slidable: slidable,
      ),
    ),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  ));
}

/// Ghost-gesture hint direction for a step.
enum _Hint { tap, swipeRight, swipeLeft, hold, pullDown }

class _Step {
  final IconData icon;
  final String Function(AppLocalizations l) title;
  final String Function(AppLocalizations l) body;
  final bool onCode; // spotlight the code (else the first account row)
  final _Hint hint;
  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    required this.hint,
    this.onCode = false,
  });
}

const _steps = [
  _Step(
    icon: Icons.touch_app_outlined,
    title: _t1,
    body: _b1,
    hint: _Hint.tap,
    onCode: true,
  ),
  _Step(
      icon: Icons.verified_user_outlined,
      title: _t2,
      body: _b2,
      hint: _Hint.swipeRight),
  _Step(icon: Icons.tune, title: _t3, body: _b3, hint: _Hint.swipeLeft),
  _Step(
      icon: Icons.inventory_2_outlined,
      title: _t4,
      body: _b4,
      hint: _Hint.hold),
  _Step(icon: Icons.refresh, title: _t5, body: _b5, hint: _Hint.pullDown),
];

String _t1(AppLocalizations l) => l.tutCodeTitle;
String _b1(AppLocalizations l) => l.tutCodeBody;
String _t2(AppLocalizations l) => l.tutSwipeRightTitle;
String _b2(AppLocalizations l) => l.tutSwipeRightBody;
String _t3(AppLocalizations l) => l.tutSwipeLeftTitle;
String _b3(AppLocalizations l) => l.tutSwipeLeftBody;
String _t4(AppLocalizations l) => l.tutLongPressTitle;
String _b4(AppLocalizations l) => l.tutLongPressBody;
String _t5(AppLocalizations l) => l.tutPullTitle;
String _b5(AppLocalizations l) => l.tutPullBody;

class _GestureTutorial extends StatefulWidget {
  final GlobalKey codeKey;
  final GlobalKey firstRowKey;
  final SlidableController? slidable;
  const _GestureTutorial({
    required this.codeKey,
    required this.firstRowKey,
    this.slidable,
  });

  @override
  State<_GestureTutorial> createState() => _GestureTutorialState();
}

class _GestureTutorialState extends State<_GestureTutorial> {
  int _step = 0;
  bool _closing = false; // simultaneous taps must not double-pop

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playDemo());
  }

  @override
  void dispose() {
    // Leave the demo row closed if we were interrupted mid-step.
    widget.slidable?.close();
    super.dispose();
  }

  /// The swipe steps physically open the first row's action pane so the user
  /// sees the real UI, not a mockup.
  void _playDemo() {
    final s = widget.slidable;
    if (s == null) return;
    switch (_steps[_step].hint) {
      case _Hint.swipeRight:
        s.openStartActionPane(duration: const Duration(milliseconds: 420));
      case _Hint.swipeLeft:
        s.openEndActionPane(duration: const Duration(milliseconds: 420));
      default:
        s.close();
    }
  }

  Rect? _targetRect() {
    final key = _steps[_step].onCode ? widget.codeKey : widget.firstRowKey;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).inflate(6);
  }

  void _advance() {
    if (_closing) return;
    if (_step >= _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _playDemo();
  }

  void _finish() {
    if (_closing) return;
    _closing = true;
    widget.slidable?.close();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final step = _steps[_step];
    final rect = _targetRect();
    final last = _step == _steps.length - 1;

    return GestureDetector(
      // Tapping anywhere advances; the card's buttons are on top of this.
      onTap: _advance,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Dimmed scrim with an animated spotlight cutout over the target.
          Positioned.fill(
            child: TweenAnimationBuilder<Rect?>(
              // begin == end so the first frame shows the target in place;
              // later steps animate from the tracked current rect to the new
              // one (TweenAnimationBuilder retargets on tween change).
              tween: RectTween(begin: rect, end: rect),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (_, r, _) => CustomPaint(
                painter: _SpotlightPainter(
                  cutout: r,
                  radius: t.isPixel ? 0 : t.radiusSm + 4,
                  border: t.accent,
                  glow: t.glow,
                ),
              ),
            ),
          ),
          // Ghost-gesture hint over the spotlight.
          if (rect != null)
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: _GestureHint(hint: step.hint, pixel: t.isPixel),
              ),
            ),
          // Bottom instruction card.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: context.rInsets(all: 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SdaPanel(
                    emphasized: true,
                    color: t.isPixel ? t.panel2 : null,
                    padding: context.rInsets(all: 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      child: Column(
                        key: ValueKey(_step),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: context.r(36),
                                height: context.r(36),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.accent.withValues(alpha: 0.14),
                                  borderRadius:
                                      BorderRadius.circular(t.radiusSm),
                                  border: Border.all(
                                      color: t.accent.withValues(alpha: 0.6),
                                      width: t.borderWidth),
                                ),
                                child: Icon(step.icon,
                                    color: t.accent, size: context.r(19)),
                              ),
                              SizedBox(width: context.r(12)),
                              Expanded(
                                child: Text(
                                  step.title(l),
                                  style: TextStyle(
                                      color: t.accent,
                                      fontSize: context.r(15),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: context.r(0.4)),
                                ),
                              ),
                              _Dots(count: _steps.length, active: _step),
                            ],
                          ),
                          SizedBox(height: context.r(10)),
                          Text(
                            step.body(l),
                            style: TextStyle(
                                color: t.text.withValues(alpha: 0.92),
                                fontSize: context.r(13.5),
                                height: 1.55),
                          ),
                          SizedBox(height: context.r(12)),
                          Row(
                            children: [
                              if (!last)
                                TextButton(
                                  onPressed: _finish,
                                  child: Text(l.tutSkip,
                                      style: TextStyle(color: t.muted)),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _advance,
                                child: Text(last ? l.tutDone : l.tutNext),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step indicator: neon dots / pixel squares.
class _Dots extends StatelessWidget {
  final int count;
  final int active;
  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(left: context.r(5)),
            width: context.r(i == active ? 14 : 6),
            height: context.r(6),
            decoration: BoxDecoration(
              color: i == active ? t.accent : t.line,
              borderRadius:
                  BorderRadius.circular(t.isPixel ? 0 : context.r(3)),
              boxShadow: i == active
                  ? t.glowShadow(blur: context.r(6), opacity: 0.5)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Dark scrim with a rounded cutout over the spotlight target plus an accent
/// border (glowing in the neon theme, hard in pixel).
class _SpotlightPainter extends CustomPainter {
  final Rect? cutout;
  final double radius;
  final Color border;
  final bool glow;
  _SpotlightPainter({
    required this.cutout,
    required this.radius,
    required this.border,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final c = cutout;
    if (c == null) {
      canvas.drawPath(
          scrim, Paint()..color = Colors.black.withValues(alpha: 0.62));
      return;
    }
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(c, Radius.circular(radius)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    final rrect = RRect.fromRectAndRadius(c, Radius.circular(radius));
    if (glow) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = border.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 1.4 : 2
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.cutout != cutout || old.border != border;
}

/// Looping ghost gesture: a touch dot that taps, holds, or slides in the
/// direction of the step's gesture. Pixel theme steps the motion on a 4px
/// grid so nothing glides.
class _GestureHint extends StatefulWidget {
  final _Hint hint;
  final bool pixel;
  const _GestureHint({required this.hint, required this.pixel});

  @override
  State<_GestureHint> createState() => _GestureHintState();
}

class _GestureHintState extends State<_GestureHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _snap(double v) => widget.pixel ? (v / 4).floorToDouble() * 4 : v;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        Offset offset = Offset.zero;
        double scale = 1, opacity = 1;
        switch (widget.hint) {
          case _Hint.tap:
            scale = v < 0.5 ? 1 - 0.18 * (v * 2) : 0.82 + 0.18 * ((v - 0.5) * 2);
            opacity = 0.9;
          case _Hint.hold:
            scale = 1 - 0.1 * v;
            opacity = 0.55 + 0.35 * v;
          case _Hint.swipeRight:
            offset = Offset(_snap(-24 + 72 * v), 0);
            opacity = v < 0.85 ? 0.9 : 0.9 * (1 - (v - 0.85) / 0.15);
          case _Hint.swipeLeft:
            offset = Offset(_snap(24 - 72 * v), 0);
            opacity = v < 0.85 ? 0.9 : 0.9 * (1 - (v - 0.85) / 0.15);
          case _Hint.pullDown:
            offset = Offset(0, _snap(-18 + 54 * v));
            opacity = v < 0.85 ? 0.9 : 0.9 * (1 - (v - 0.85) / 0.15);
        }
        return Center(
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape:
                        widget.pixel ? BoxShape.rectangle : BoxShape.circle,
                    color: t.accent.withValues(alpha: 0.35),
                    border: Border.all(color: t.accent, width: 2),
                    boxShadow: t.glowShadow(blur: 10, opacity: 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
