import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import 'widgets/app_logo.dart';
import 'widgets/motion.dart';
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
    final ok = await ref.read(appControllerProvider.notifier).unlock(passKey);
    if (!mounted || ok) return;
    setState(() {
      _error = l.unlockInvalid;
      _shake++;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(appControllerProvider.notifier).unlock(
          _controller.text,
        );
    if (!mounted) return;
    if (!ok) {
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
      appBar: AppBar(title: Text(l.unlockTitle)),
      body: ScanlineOverlay(
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
                TextField(
                  controller: _controller,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l.passkeyLabel,
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                SizedBox(height: context.r(16)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? SizedBox(
                            height: context.r(18),
                            width: context.r(18),
                            child: CircularProgressIndicator(
                                strokeWidth: context.r(2)),
                          )
                        : Text(l.unlockButton),
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
      ),
    );
  }
}
