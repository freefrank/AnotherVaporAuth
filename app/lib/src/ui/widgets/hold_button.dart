import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's single hold-to-confirm control for irreversible "accept"
/// actions (trade accepts, family joins, mobileconf accepts): press and hold
/// for [duration]; a progress ring fills and haptic ticks fire at shrinking
/// intervals (an accelerating "charging" feel), ending in a medium impact
/// when the action commits. Early release cancels and resets.
///
/// On press the control gives immediate feedback so it never reads as a dead
/// button: it scales up slightly and the ring jumps straight to the halfway
/// mark, then the real timer drives the second half. The shown progress is
/// front-loaded (0→½ is a "gift"); the hold *length* is unchanged — commit
/// still requires the full [duration] of held time.
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
/// under `tester.pump(duration)`'s fake-async elapse. Elapsed time is counted
/// in whole ticks, so UI jank can only stretch a hold, never shorten it —
/// timing drift errs on the safe side for an irreversible action.
///
/// Accessibility: assistive technologies cannot perform a timed hold, so the
/// control exposes standard button semantics whose activation confirms
/// directly (the pill's [label], or [semanticLabel] for the round variant).
/// When that direct activation would skip a safety gate the hold provides
/// (e.g. batch "accept all"), pass [onSemanticConfirmed] to give AT users an
/// alternative confirmed path (typically a dialog) instead of [onConfirmed].
class HoldToConfirmButton extends StatefulWidget {
  final String? label; // pill 变体
  final IconData? icon; // round 变体
  final String? semanticLabel; // round 变体的无障碍标签
  final Color color;
  final Duration duration;
  final VoidCallback onConfirmed;

  /// Fired instead of [onConfirmed] on semantic (assistive-tech) activation.
  /// AT 的合成点按没有长按这道门槛 —— 批量等高危操作在这里改走带二次确认的
  /// 路径(如弹窗),避免一次双击就直接提交。null 时语义激活仍走 [onConfirmed]。
  final VoidCallback? onSemanticConfirmed;
  final bool enabled;
  final bool holdEnabled;
  final bool hapticsEnabled;

  const HoldToConfirmButton({
    super.key,
    required String this.label,
    required this.color,
    required this.onConfirmed,
    this.onSemanticConfirmed,
    this.duration = const Duration(milliseconds: 900),
    this.enabled = true,
    this.holdEnabled = true,
    this.hapticsEnabled = true,
  })  : icon = null,
        semanticLabel = null;

  const HoldToConfirmButton.round({
    super.key,
    required IconData this.icon,
    required this.color,
    required this.onConfirmed,
    this.onSemanticConfirmed,
    this.semanticLabel = 'confirm',
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
  bool _pressed = false; // 手指按下期间为真：驱动按钮放大反馈
  late List<int> _haptics =
      HoldToConfirmButton.hapticTimesMs(widget.duration.inMilliseconds);

  /// 真实计时进度 [0,1]：`onConfirmed` 只认它，长按总时长不受显示层影响。
  double get _rawProgress =>
      (_elapsedMs / widget.duration.inMilliseconds).clamp(0.0, 1.0);

  /// 显示进度：按下瞬间即跳到一半，之后真实计时驱动后半程填满。前半程是
  /// “送”的即时反馈——按钮一按就有明显动静，不再像坏掉；实际计时逻辑
  /// （`_elapsedMs >= duration` 才提交）分毫未改，总时长不变。
  double get _displayProgress => _pressed ? 0.5 + 0.5 * _rawProgress : 0.0;

  void _start([_]) {
    if (!widget.enabled || !widget.holdEnabled) return;
    _timer?.cancel();
    _elapsedMs = 0;
    _nextHaptic = 0;
    _pressed = true;
    _timer = Timer.periodic(_tick, (_) => _onTick());
    setState(() {});
  }

  void _onTick() {
    if (!mounted) return;
    // 长按进行中被禁用（busy 状态、设置切换）必须立即作废,绝不补触发。
    if (!widget.enabled || !widget.holdEnabled) {
      _cancel();
      return;
    }
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
      _pressed = false; // 提交完成：进度清空、按钮回落，即使手指还没抬起
      if (widget.hapticsEnabled) HapticFeedback.mediumImpact();
      setState(() {});
      widget.onConfirmed();
      return;
    }
    setState(() {});
  }

  void _cancel([_]) {
    // 抬手/取消可能发生在计时器已结束（提交完成）之后：此时仍要确保按钮
    // 回落到常态，所以不能只在 _timer != null 时才处理。
    if (_timer == null && !_pressed) return;
    _timer?.cancel();
    _timer = null;
    _elapsedMs = 0;
    _nextHaptic = 0;
    _pressed = false;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant HoldToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !widget.holdEnabled) _cancel();
    if (oldWidget.duration != widget.duration) {
      _haptics = HoldToConfirmButton.hapticTimesMs(widget.duration.inMilliseconds);
      if (_timer != null) _cancel(); // haptic 索引已错位,作废本次长按
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _displayProgress;
    final child = widget.icon != null
        // 48dp 命中区域包住 36dp 视觉(a11y 触摸目标,同 _RoundAction 先例)。
        ? SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
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
              ),
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

    // 辅助技术做不了计时手势(合成点按 = 立即 down→up,永不触发),
    // 所以暴露标准按钮语义:语义激活直接确认。
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: widget.enabled,
      label: widget.label ?? widget.semanticLabel ?? 'confirm',
      onTap: widget.enabled
          ? (widget.onSemanticConfirmed ?? widget.onConfirmed)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 长按关闭（设置开关）时退化为普通点按 —— 单条操作即点即行，
        // 批量操作的安全底线由调用方保留弹窗（见 Task 10b）。
        onTap:
            !widget.holdEnabled && widget.enabled ? widget.onConfirmed : null,
        onTapDown: _start,
        onTapUp: _cancel,
        onTapCancel: _cancel,
        // 按下即放大：给出即时“已响应”反馈，长按不再像点了个坏按钮。
        // 松手/完成后 _pressed 复位，弹回常态。
        child: AnimatedScale(
          scale: _pressed ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: child),
        ),
      ),
    );
  }
}
