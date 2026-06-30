import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/models/session_data.dart';
import '../core/protocol/authenticator_linker.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/stepper3.dart';

class AddAuthenticatorScreen extends ConsumerStatefulWidget {
  final SessionData session;
  const AddAuthenticatorScreen({super.key, required this.session});

  @override
  ConsumerState<AddAuthenticatorScreen> createState() =>
      _AddAuthenticatorScreenState();
}

enum _Step { working, needPhone, finalize, done, failed }

class _AddAuthenticatorScreenState
    extends ConsumerState<AddAuthenticatorScreen> {
  late final AuthenticatorLinker _linker;
  final _phone = TextEditingController();
  final _sms = TextEditingController();
  final _revocation = TextEditingController();

  _Step _step = _Step.working;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _linker = AuthenticatorLinker(ref.read(apiClientProvider), widget.session);
    _add();
  }

  @override
  void dispose() {
    _phone.dispose();
    _sms.dispose();
    _revocation.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _step = _Step.working;
    });
    try {
      final result = await _linker.addAuthenticator();
      switch (result) {
        case LinkResult.mustProvidePhoneNumber:
          setState(() {
            _busy = false;
            _step = _Step.needPhone;
          });
          break;
        case LinkResult.awaitingFinalization:
          // Save immediately — losing these secrets would be catastrophic.
          await ref
              .read(appControllerProvider.notifier)
              .persistAccount(_linker.linkedAccount!);
          setState(() {
            _busy = false;
            _step = _Step.finalize;
            _message = _linker.linkedAccount!.revocationCode;
          });
          break;
        case LinkResult.authenticatorPresent:
          _failWith(l.addErrPresent);
          break;
        case LinkResult.mustConfirmEmail:
          _failWith(l.addErrConfirmEmail);
          break;
        case LinkResult.accountLocked:
          _failWith(l.addErrLocked);
          break;
        case LinkResult.rateLimited:
          _failWith(l.addErrRateLimited);
          break;
        case LinkResult.generalFailure:
          _failWith(l.addErrFailed);
          break;
      }
    } catch (e) {
      _failWith('$e');
    }
  }

  Future<void> _submitPhone() async {
    _linker.phoneNumber = _phone.text.trim();
    await _add();
  }

  Future<void> _finalize() async {
    final l = AppLocalizations.of(context);
    final account = _linker.linkedAccount!;
    if (_revocation.text.trim().toUpperCase() !=
        (account.revocationCode ?? '').toUpperCase()) {
      setState(() => _message = l.addAuthConfirmRevocation);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _linker.finalize(_sms.text.trim());
      if (result == FinalizeResult.success) {
        await ref
            .read(appControllerProvider.notifier)
            .persistAccount(account);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _step = _Step.done;
        });
      } else if (result == FinalizeResult.badSmsCode) {
        setState(() {
          _busy = false;
          _message = l.addErrBadSms;
        });
      } else {
        _failWith(l.addErrFinalize('$result'));
      }
    } catch (e) {
      _failWith('$e');
    }
  }

  void _failWith(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.failed;
      _message = msg;
    });
  }

  int get _stepIndex {
    switch (_step) {
      case _Step.needPhone:
        return 0;
      case _Step.finalize:
        return 1;
      case _Step.done:
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final showStepper = _step != _Step.working && _step != _Step.failed;
    return Scaffold(
      appBar: AppBar(title: Text(l.addAuthTitle)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showStepper) ...[
                    Stepper3(
                      current: _stepIndex,
                      labels: [
                        l.addAuthStepPhone,
                        l.addAuthStepSms,
                        l.addAuthStepRevocation,
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                  // Animated horizontal slide between steps.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween(
                        begin: const Offset(0.12, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildStep(l),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l) {
    switch (_step) {
      case _Step.working:
        return const Center(child: CircularProgressIndicator());
      case _Step.needPhone:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.addAuthPhonePrompt),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+1 555 0100',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submitPhone,
              child: Text(l.commonConfirm),
            ),
          ],
        );
      case _Step.finalize:
        final t = Theme.of(context).extension<SdaTokens>()!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.warn.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(t.radius),
                border: Border.all(color: t.warn.withValues(alpha: 0.6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: t.warn, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.addAuthRevocationWarn(_message ?? ''),
                        style: TextStyle(color: t.text)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(l.addAuthSmsPrompt),
            const SizedBox(height: 8),
            TextField(
              controller: _sms,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Text(l.addAuthConfirmRevocation),
            const SizedBox(height: 8),
            TextField(
              controller: _revocation,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _finalize,
              child: Text(l.commonConfirm),
            ),
          ],
        );
      case _Step.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 48, color: Colors.green),
            const SizedBox(height: 12),
            Text(l.addAuthLinked, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(l.commonOk),
            ),
          ],
        );
      case _Step.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('${l.commonError}: ${_message ?? ''}',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.commonClose),
            ),
          ],
        );
    }
  }
}
