import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A submit button that freezes for [cooldown] after each press to prevent
/// accidental rapid re-submits. While frozen it is non-interactive and shows a
/// countdown that ticks down in 0.01s steps — the remaining seconds (2 decimals)
/// plus a progress line that drains as the freeze elapses.
class CooldownButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration cooldown;
  final bool expand;

  const CooldownButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.cooldown = const Duration(seconds: 1),
    this.expand = false,
  });

  @override
  State<CooldownButton> createState() => _CooldownButtonState();
}

class _CooldownButtonState extends State<CooldownButton> {
  static const Duration _tick = Duration(milliseconds: 10); // 0.01s steps
  Timer? _timer;
  double _remaining = 0; // seconds left in the freeze

  bool get _frozen => _remaining > 0;

  void _press() {
    if (_frozen || widget.onPressed == null) return;
    widget.onPressed!();
    _timer?.cancel();
    setState(() => _remaining = widget.cooldown.inMilliseconds / 1000.0);
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= 0.01;
        if (_remaining <= 0) {
          _remaining = 0;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>();
    final total = widget.cooldown.inMilliseconds / 1000.0;
    final frac = _frozen ? (_remaining / total).clamp(0.0, 1.0) : 0.0;
    final accent = t?.accent ?? Theme.of(context).colorScheme.primary;

    final button = FilledButton(
      onPressed: (_frozen || widget.onPressed == null) ? null : _press,
      child: _frozen
          ? Text('${_remaining.toStringAsFixed(2)}s')
          : widget.child,
    );

    return Stack(
      children: [
        widget.expand ? SizedBox(width: double.infinity, child: button) : button,
        if (_frozen)
          Positioned(
            left: 10,
            right: 10,
            bottom: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 3,
                backgroundColor: accent.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
      ],
    );
  }
}
