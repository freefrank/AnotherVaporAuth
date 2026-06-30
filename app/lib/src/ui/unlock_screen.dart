import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FloatingLogo(child: AppLogo(size: 84)),
                const SizedBox(height: 16),
                Text(l.unlockPrompt, textAlign: TextAlign.center),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.unlockButton),
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
