import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import 'widgets/app_logo.dart';
import 'widgets/motion.dart';
import 'widgets/pin_field.dart';
import 'widgets/scanline_overlay.dart';

/// Mandatory first-run PIN setup: the local store must be protected by a
/// 6-digit unlock PIN before it can be used. Shown at the app root when there
/// are accounts but no encryption passkey yet.
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  int _shake = 0;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final pin = _pin.text;
    if (pin.length != 6) {
      setState(() => _error = l.pinSixDigits);
      return;
    }
    if (pin != _confirm.text) {
      setState(() {
        _error = l.pinMismatch;
        _shake++;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok =
        await ref.read(appControllerProvider.notifier).changePasskey(null, pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = l.commonError;
        _shake++;
      });
    }
    // On success the store becomes encrypted (still unlocked) and the app root
    // rebuilds into the home screen.
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.pinSetupTitle), automaticallyImplyLeading: false),
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
                    FloatingLogo(child: AppLogo(size: context.r(72))),
                    SizedBox(height: context.r(16)),
                    Text(l.pinSetupPrompt, textAlign: TextAlign.center),
                    SizedBox(height: context.r(16)),
                    PinField(
                      controller: _pin,
                      label: l.pinLabel,
                      autofocus: true,
                    ),
                    SizedBox(height: context.r(12)),
                    PinField(
                      controller: _confirm,
                      label: l.pinConfirmLabel,
                      onSubmitted: (_) => _submit(),
                      onCompleted: (_) => _submit(),
                      errorText: _error,
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
                            : Text(l.pinSetButton),
                      ),
                    ),
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
