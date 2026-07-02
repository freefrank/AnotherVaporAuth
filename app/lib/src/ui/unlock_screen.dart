import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import 'widgets/app_logo.dart';
import 'widgets/cyber_ambient.dart';
import 'widgets/motion.dart';
import 'widgets/pin_field.dart';
import 'widgets/pixel_ambient.dart';
import 'widgets/scanline_overlay.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  int _shake = 0;
  bool _canBio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeBiometric();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybeBiometric() async {
    final bio = ref.read(biometricUnlockProvider);
    final enabled = (await bio.isEnabled) && (await bio.isSupported);
    if (!mounted) return;
    setState(() => _canBio = enabled);
    if (enabled) _biometricUnlock();
  }

  Future<void> _biometricUnlock() async {
    final l = AppLocalizations.of(context);
    final passKey =
        await ref.read(biometricUnlockProvider).unlock(l.unlockBiometricReason);
    if (!mounted || passKey == null) return;
    // Show the themed loading state while the DEK is unwrapped + accounts decrypt.
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(appControllerProvider.notifier).unlock(passKey);
    if (!mounted || ok) return;
    setState(() {
      _busy = false;
      _error = l.unlockInvalid;
      _shake++;
    });
  }

  Future<void> _submit() async {
    if (_busy || _controller.text.length < 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(appControllerProvider.notifier).unlock(
          _controller.text,
        );
    if (!mounted) return;
    if (!ok) {
      _controller.clear(); // let the user retype (and re-trigger auto-submit)
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).unlockInvalid;
        _shake++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      // Hide the chrome during the full-screen themed loading state.
      appBar: _busy ? null : AppBar(title: Text(l.unlockTitle)),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _busy ? const _UnlockLoading() : _buildForm(context, l),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l) {
    return ScanlineOverlay(
      key: const ValueKey('form'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ShakeWidget(
            trigger: _shake,
            child: Padding(
              padding: context.rInsets(all: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingLogo(child: AppLogo(size: context.r(84))),
                  SizedBox(height: context.r(16)),
                  Text(l.unlockPrompt, textAlign: TextAlign.center),
                  SizedBox(height: context.r(16)),
                  PinField(
                    controller: _controller,
                    label: l.pinLabel,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    onCompleted: (_) => _submit(), // auto-unlock at 6 digits
                    errorText: _error,
                  ),
                  SizedBox(height: context.r(16)),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(l.unlockButton),
                    ),
                  ),
                  if (_canBio) ...[
                    SizedBox(height: context.r(12)),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _biometricUnlock,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(l.unlockWithBiometric),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen themed loading shown while the vault DEK is unwrapped and the
/// accounts are decrypted. Neon and Pixel each get their own ambient backdrop.
class _UnlockLoading extends ConsumerWidget {
  const _UnlockLoading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final l = AppLocalizations.of(context);
    final pixel = t.isPixel;
    return Container(
      key: const ValueKey('loading'),
      decoration: BoxDecoration(color: t.bg, gradient: t.bgGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
              child: pixel ? const PixelAmbient() : const CyberAmbient()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingLogo(child: AppLogo(size: context.r(96))),
                SizedBox(height: context.r(30)),
                _ScanBar(tokens: t),
                SizedBox(height: context.r(18)),
                Text(
                  l.unlockLoading,
                  style: TextStyle(
                    color: t.muted,
                    letterSpacing: pixel ? 1 : 3,
                    fontSize: context.r(13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A theme-aware progress bar that FILLS instead of looping — an endless sweep
/// reads as "who knows how long", a filling bar reads as "almost there".
///
/// There is no real progress signal from the unlock, so the fill is a cubic
/// ease-out sized to the typical unlock (well under a second now that the KDF
/// is a single round): it charges quickly to ~90%, then creeps asymptotically
/// toward 98% on slower paths (e.g. the one-time 100k-round legacy re-wrap);
/// the screen swaps away the moment the unlock completes. Pixel theme
/// quantises the fill into hard blocks.
class _ScanBar extends StatefulWidget {
  final SdaTokens tokens;
  const _ScanBar({required this.tokens});

  @override
  State<_ScanBar> createState() => _ScanBarState();
}

class _ScanBarState extends State<_ScanBar>
    with SingleTickerProviderStateMixin {
  // Full curve duration: reaches ~90% around the typical unlock time and
  // saturates slowly after; never completes on its own.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _fill(double t) {
    // Cubic ease-out to 0.9 over the first ~30% of the timeline (≈0.6s),
    // then a slow linear creep to 0.98.
    if (t < 0.3) {
      final k = t / 0.3;
      return 0.9 * (1 - (1 - k) * (1 - k) * (1 - k));
    }
    return 0.9 + 0.08 * ((t - 0.3) / 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final pixel = tokens.isPixel;
    return Container(
      width: context.r(180),
      decoration: BoxDecoration(
        boxShadow: tokens.glowShadow(blur: 14, opacity: 0.5),
        borderRadius: BorderRadius.circular(pixel ? 0 : 4),
        border: pixel ? Border.all(color: tokens.line, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(pixel ? 0 : 4),
        child: SizedBox(
          height: context.r(pixel ? 10 : 5),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              var v = _fill(_c.value);
              // Pixel: fill in hard 1/12 blocks instead of gliding.
              if (pixel) v = (v * 12).floorToDouble() / 12;
              return LinearProgressIndicator(
                value: v,
                backgroundColor: pixel ? tokens.bg : tokens.line,
                valueColor: AlwaysStoppedAnimation(tokens.accent),
              );
            },
          ),
        ),
      ),
    );
  }
}
