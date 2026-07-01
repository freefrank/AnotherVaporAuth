import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/session_data.dart';
import '../core/protocol/authenticator_linker.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/stepper3.dart';

class AddAuthenticatorScreen extends ConsumerStatefulWidget {
  final SessionData session;
  final String? password; // saved to the new account for auto-refresh, if given
  const AddAuthenticatorScreen(
      {super.key, required this.session, this.password});

  @override
  ConsumerState<AddAuthenticatorScreen> createState() =>
      _AddAuthenticatorScreenState();
}

enum _Step { working, needPhone, finalize, done, failed, present }

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
    // Defer to after the first frame: _add() reads AppLocalizations.of(context),
    // which must not be accessed during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _add();
    });
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
          if (widget.password != null && widget.password!.isNotEmpty) {
            _linker.linkedAccount!.password = widget.password;
          }
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
          // Not an error: guide the user through removing the existing
          // authenticator, then let them retry.
          setState(() {
            _busy = false;
            _step = _Step.present;
          });
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
    final showStepper = _step != _Step.working &&
        _step != _Step.failed &&
        _step != _Step.present;
    return Scaffold(
      appBar: AppBar(title: Text(l.addAuthTitle)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: context.rInsets(all: 24),
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
                    SizedBox(height: context.r(28)),
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
            SizedBox(height: context.r(12)),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+1 555 0100',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: context.r(12)),
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
              padding: context.rInsets(all: 14),
              decoration: BoxDecoration(
                color: t.warn.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(t.radius),
                border: Border.all(color: t.warn.withValues(alpha: 0.6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: t.warn, size: context.r(20)),
                  SizedBox(width: context.r(10)),
                  Expanded(
                    child: Text(l.addAuthRevocationWarn(_message ?? ''),
                        style: TextStyle(color: t.text)),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.r(16)),
            Text(_linker.activatesByEmail
                ? l.addAuthEmailPrompt
                : l.addAuthSmsPrompt),
            SizedBox(height: context.r(8)),
            TextField(
              controller: _sms,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            SizedBox(height: context.r(12)),
            Text(l.addAuthConfirmRevocation),
            SizedBox(height: context.r(8)),
            TextField(
              controller: _revocation,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            SizedBox(height: context.r(16)),
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
            Icon(Icons.check_circle_outline,
                size: context.r(48), color: Colors.green),
            SizedBox(height: context.r(12)),
            Text(l.addAuthLinked, textAlign: TextAlign.center),
            SizedBox(height: context.r(16)),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(l.commonOk),
            ),
          ],
        );
      case _Step.present:
        final t = Theme.of(context).extension<SdaTokens>()!;
        Widget step(int n, String text) => Padding(
              padding: context.rInsets(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: context.r(24),
                    height: context.r(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: t.accent.withValues(alpha: 0.6)),
                    ),
                    child: Text('$n',
                        style: TextStyle(
                            color: t.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: context.r(13))),
                  ),
                  SizedBox(width: context.r(12)),
                  Expanded(child: Text(text)),
                ],
              ),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.shield_outlined,
                size: context.r(44), color: t.accent),
            SizedBox(height: context.r(12)),
            Text(l.addPresentTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: context.r(18), fontWeight: FontWeight.bold)),
            SizedBox(height: context.r(10)),
            Text(l.addPresentIntro, textAlign: TextAlign.center),
            SizedBox(height: context.r(20)),
            step(1, l.addPresentStep1),
            step(2, l.addPresentStep2),
            // The 2FA management page + a copy button (no external browser dep).
            Padding(
              padding: context.rInsets(left: 36, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      l.addPresentManageUrl,
                      style: TextStyle(
                          color: t.accent,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                  IconButton(
                    tooltip: l.commonCopy,
                    icon: Icon(Icons.copy, size: context.r(18)),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: 'https://${l.addPresentManageUrl}'));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.addPresentCopiedUrl)),
                      );
                    },
                  ),
                ],
              ),
            ),
            step(3, l.addPresentStep3),
            SizedBox(height: context.r(8)),
            FilledButton.icon(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
            SizedBox(height: context.r(8)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.commonClose),
            ),
          ],
        );
      case _Step.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: context.r(48), color: Colors.redAccent),
            SizedBox(height: context.r(12)),
            Text('${l.commonError}: ${_message ?? ''}',
                textAlign: TextAlign.center),
            SizedBox(height: context.r(16)),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.commonClose),
            ),
          ],
        );
    }
  }
}
