import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's single hold-to-confirm control for irreversible "accept"
/// actions (trade accepts, family joins, mobileconf accepts): press and hold
/// for [duration]; a progress ring fills and haptic ticks fire at shrinking
/// intervals (an accelerating "charging" feel), ending in a medium impact
/// when the action commits. Early release cancels and resets.
///
/// Two shapes: pill ([HoldToConfirmButton.new] with [label]) and round icon
/// ([HoldToConfirmButton.round] — drop-in for the confirmation card's ✓).
/// [holdEnabled] false (settings toggle) degrades to a plain tap;
/// [hapticsEnabled] false mutes all haptics.
///
/// Progress is driven by a periodic [Timer] (like `CooldownButton`) rather
/// than an `AnimationController`/ticker: a ticker's elapsed time is anchored
/// to the scheduler's frame clock, which only advances on painted frames, so
/// a single `pump(duration)` after starting a hold would not reliably drive
/// it to completion in widget tests. A wall-clock timer advances correctly
/// under `tester.pump(duration)`'s fake-async elapse.
class HoldToConfirmButton extends StatefulWidget {
  final String? label; // pill 变体
  final IconData? icon; // round 变体
  final Color color;
  final Duration duration;
  final VoidCallback onConfirmed;
  final bool enabled;
  final bool holdEnabled;
  final bool hapticsEnabled;

  const HoldToConfirmButton({
    super.key,
    required String this.label,
    required this.color,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 900),
    this.enabled = true,
    this.holdEnabled = true,
    this.hapticsEnabled = true,
  }) : icon = null;

  const HoldToConfirmButton.round({
    super.key,
    required IconData this.icon,
    required this.color,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 900),
    this.enabled = true,
    this.holdEnabled = true,
    this.hapticsEnabled = true,
  }) : label = null;

  /// Haptic tick times (ms since press). Intervals shrink geometrically
  /// (factor 0.72, floor 45ms) so the pulse audibly accelerates. Pure and
  /// deterministic for unit tests.
  static List<int> hapticTimesMs(int totalMs) {
    final times = <int>[0];
    var interval = totalMs * 0.30;
    var t = interval;
    while (t < totalMs) {
      times.add(t.round());
      interval = interval * 0.72 < 45 ? 45 : interval * 0.72;
      t += interval;
    }
    return times;
  }

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> {
  static const Duration _tick = Duration(milliseconds: 16); // ~60fps 步进
  Timer? _timer;
  int _elapsedMs = 0;
  int _nextHaptic = 0;
  late List<int> _haptics =
      HoldToConfirmButton.hapticTimesMs(widget.duration.inMilliseconds);

  double get _progress =>
      (_elapsedMs / widget.duration.inMilliseconds).clamp(0.0, 1.0);

  void _start([_]) {
    if (!widget.enabled || !widget.holdEnabled) return;
    _timer?.cancel();
    _elapsedMs = 0;
    _nextHaptic = 0;
    _timer = Timer.periodic(_tick, (_) => _onTick());
    setState(() {});
  }

  void _onTick() {
    if (!mounted) return;
    _elapsedMs += _tick.inMilliseconds;
    while (_nextHaptic < _haptics.length && _elapsedMs >= _haptics[_nextHaptic]) {
      if (widget.hapticsEnabled) HapticFeedback.lightImpact();
      _nextHaptic++;
    }
    if (_elapsedMs >= widget.duration.inMilliseconds) {
      _timer?.cancel();
      _timer = null;
      _elapsedMs = 0;
      _nextHaptic = 0;
      if (widget.hapticsEnabled) HapticFeedback.mediumImpact();
      setState(() {});
      widget.onConfirmed();
      return;
    }
    setState(() {});
  }

  void _cancel([_]) {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    _elapsedMs = 0;
    _nextHaptic = 0;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant HoldToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _haptics = HoldToConfirmButton.hapticTimesMs(widget.duration.inMilliseconds);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final child = widget.icon != null
        ? SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.4,
                  color: widget.color,
                  backgroundColor: widget.color.withValues(alpha: 0.25),
                ),
                Icon(widget.icon, color: widget.color, size: 18),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.16),
              border: Border.all(color: widget.color),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.4,
                    color: widget.color,
                    backgroundColor: widget.color.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: 8),
                Text(widget.label!,
                    style: TextStyle(
                        color: widget.color, fontWeight: FontWeight.w600)),
              ],
            ),
          );

    return GestureDetector(
      // 长按关闭（设置开关）时退化为普通点按 —— 单条操作即点即行，
      // 批量操作的安全底线由调用方保留弹窗（见 Task 10b）。
      onTap: !widget.holdEnabled && widget.enabled ? widget.onConfirmed : null,
      onTapDown: _start,
      onTapUp: _cancel,
      onTapCancel: _cancel,
      child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: child),
    );
  }
}
