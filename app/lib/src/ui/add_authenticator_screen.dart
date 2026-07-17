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
  const AddAuthenticatorScreen({
    super.key,
    required this.session,
    this.password,
  });

  @override
  ConsumerState<AddAuthenticatorScreen> createState() =>
      _AddAuthenticatorScreenState();
}

enum _Step {
  working,
  needPhone,
  finalize,
  done,
  failed,
  present,
  challengeCode,
}

class _AddAuthenticatorScreenState
    extends ConsumerState<AddAuthenticatorScreen> {
  late final AuthenticatorLinker _linker;
  final _phone = TextEditingController();
  final _sms = TextEditingController();
  final _revocation = TextEditingController();
  final _challenge = TextEditingController();

  _Step _step = _Step.working;
  String? _message;
  bool _busy = false;

  /// True only while [_moveInSubmit]'s moveInContinue call is in flight — the
  /// one window where Steam may already have swapped the token, so popping
  /// would orphan it. Every other step's request persists via pre-captured
  /// notifiers and stays backable.
  bool _lockPop = false;

  /// True once the account arrived via move-in rather than a fresh link —
  /// only changes which "success" wording the done step shows.
  bool _movedIn = false;

  /// Set only when a move-in succeeded on Steam's side but the local save
  /// failed. The old authenticator is already dead and these are the only
  /// copies of the new one, so the failed step must show them verbatim
  /// instead of a plain error. See [_moveInSubmit].
  ({String code, String secret})? _fatalSecrets;

  /// Whether the "remove it elsewhere" fallback is expanded on [_Step.present].
  bool _showFallback = false;

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
    _challenge.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    // Captured before any await: reading `ref` on a disposed State throws,
    // and the immediate save below must not depend on it.
    final controller = ref.read(appControllerProvider.notifier);
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
          final saved = await controller.persistAccount(_linker.linkedAccount!);
          // If the local save failed we must NOT finalize — Steam Guard would
          // attach to the account while AVA holds no secret to generate codes.
          // Surface the revocation code so the user can remove the not-yet-
          // finalized authenticator and recover.
          if (!saved) {
            // No rescue-screen arming here: finalize was skipped, so nothing
            // is attached on Steam's side yet — the state is fully
            // recoverable (remove the pending authenticator, retry). The
            // rescue takeover's "old authenticator is dead" copy is only
            // true after a move-in continue or a successful finalize.
            _failWith(
              l.addErrSaveFailed(_linker.linkedAccount!.revocationCode ?? '—'),
            );
            break;
          }
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
        case LinkResult.challengeEmailSent:
        case LinkResult.movedIn:
        case LinkResult.badChallengeCode:
          // Move-in outcomes: only moveInStart/moveInContinue produce these,
          // never addAuthenticator. Handled in _moveInStart/_moveInSubmit.
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

  /// Asks Steam to mail the move-in challenge code. Read-only account-side —
  /// nothing is revoked until [_moveInSubmit].
  Future<void> _moveInStart() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _linker.moveInStart();
      if (!mounted) return;
      switch (result) {
        case LinkResult.challengeEmailSent:
          setState(() {
            _busy = false;
            _step = _Step.challengeCode;
          });
          break;
        case LinkResult.accountLocked:
          _failWith(l.addErrLocked);
          break;
        case LinkResult.rateLimited:
          _failWith(l.addErrRateLimited);
          break;
        default:
          _failWith(l.addErrFailed);
          break;
      }
    } catch (e) {
      _failWith('$e');
    }
  }

  /// Submits the mailed code. On success Steam has ALREADY swapped the token —
  /// the old authenticator is dead, there is no finalize step and no rollback,
  /// so the save must happen right here and a failed save is a data-loss
  /// emergency, not an ordinary error.
  Future<void> _moveInSubmit() async {
    final l = AppLocalizations.of(context);
    // Captured before any await: reading `ref` after unmount throws, and the
    // save/surfacing below must run even if this route is gone by then.
    final controller = ref.read(appControllerProvider.notifier);
    final rescue = ref.read(moveInRescueProvider.notifier);
    setState(() {
      _busy = true;
      _lockPop = true;
      _message = null;
    });
    try {
      final result = await _linker.moveInContinue(_challenge.text.trim());
      switch (result) {
        case LinkResult.movedIn:
          final account = _linker.linkedAccount!;
          if (widget.password != null && widget.password!.isNotEmpty) {
            account.password = widget.password;
          }
          final saved = await controller.persistAccount(account);
          if (!saved) {
            final secrets = (
              code: account.revocationCode ?? '—',
              secret: account.sharedSecret ?? '—',
            );
            // Nothing to undo — the old token is gone either way. Root-level
            // fallback FIRST: it must exist even if this State is already
            // disposed (see moveInRescueProvider).
            rescue.set(secrets);
            if (!mounted) return;
            setState(() {
              _busy = false;
              _step = _Step.failed;
              _message = null;
              _fatalSecrets = secrets;
            });
            break;
          }
          if (!mounted) return;
          setState(() {
            _busy = false;
            _movedIn = true;
            _step = _Step.done;
          });
          break;
        case LinkResult.badChallengeCode:
          if (!mounted) return;
          setState(() {
            _busy = false;
            _message = l.addErrBadChallengeCode;
          });
          break;
        case LinkResult.accountLocked:
          _failWith(l.addErrLocked);
          break;
        case LinkResult.rateLimited:
          _failWith(l.addErrRateLimited);
          break;
        default:
          _failWith(l.addErrFailed);
          break;
      }
    } catch (e) {
      _failWith('$e');
    } finally {
      _lockPop = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _finalize() async {
    final l = AppLocalizations.of(context);
    // Captured before any await: reading `ref` on a disposed State throws,
    // and the post-finalize save / rescue-arming must not depend on it.
    final controller = ref.read(appControllerProvider.notifier);
    final rescue = ref.read(moveInRescueProvider.notifier);
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
        final saved = await controller.persistAccount(account);
        if (!saved) {
          // Steam Guard is active but nothing reached disk — arm the
          // root-level fallback BEFORE the mounted-guarded inline error, so
          // a disposed screen still surfaces the revocation code.
          rescue.set((
            code: account.revocationCode ?? '—',
            secret: account.sharedSecret ?? '—',
          ));
          _failWith(l.addErrSaveFailed(account.revocationCode ?? '—'));
          return;
        }
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
    final showStepper =
        _step != _Step.working &&
        _step != _Step.failed &&
        _step != _Step.present &&
        _step != _Step.challengeCode;
    return PopScope(
      // Only the irreversible move-in window blocks back (see _lockPop) —
      // every other step may be abandoned; in-flight saves survive unmount
      // via the pre-captured notifiers.
      canPop: !_lockPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).addMoveInPopBlocked),
            ),
          );
        }
      },
      child: Scaffold(
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
        final t = Theme.of(context).extension<AvaTokens>()!;
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
                  Icon(
                    Icons.warning_amber_rounded,
                    color: t.warn,
                    size: context.r(20),
                  ),
                  SizedBox(width: context.r(10)),
                  Expanded(
                    child: Text(
                      l.addAuthRevocationWarn(_message ?? ''),
                      style: TextStyle(color: t.text),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.r(16)),
            Text(
              _linker.activatesByEmail
                  ? l.addAuthEmailPrompt
                  : l.addAuthSmsPrompt,
            ),
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
            Icon(
              Icons.check_circle_outline,
              size: context.r(48),
              color: Colors.green,
            ),
            SizedBox(height: context.r(12)),
            Text(
              _movedIn ? l.addMoveInDone : l.addAuthLinked,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.r(16)),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(l.commonOk),
            ),
          ],
        );
      case _Step.present:
        final t = Theme.of(context).extension<AvaTokens>()!;
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
                  border: Border.all(color: t.accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: t.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: context.r(13),
                  ),
                ),
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
            Icon(Icons.shield_outlined, size: context.r(44), color: t.accent),
            SizedBox(height: context.r(12)),
            Text(
              l.addPresentTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.r(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.r(10)),
            Text(l.addPresentIntro, textAlign: TextAlign.center),
            SizedBox(height: context.r(20)),
            // Preferred path: move the token here in-app. Removing it via the
            // website (the fallback below) costs the user a 15-day trade hold.
            FilledButton.icon(
              onPressed: _busy ? null : _moveInStart,
              icon: const Icon(Icons.move_down),
              label: Text(l.addMoveInButton),
            ),
            SizedBox(height: context.r(8)),
            Text(
              _busy ? l.addMoveInSending : l.addMoveInBlurb,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: context.r(12), color: t.muted),
            ),
            SizedBox(height: context.r(20)),
            // Fallback for users whose account email is unreachable — they can
            // only remove it elsewhere and come back.
            TextButton.icon(
              onPressed: () => setState(() => _showFallback = !_showFallback),
              icon: Icon(_showFallback ? Icons.expand_less : Icons.expand_more),
              label: Text(l.addPresentFallbackTitle),
            ),
            if (!_showFallback) SizedBox(height: context.r(4)),
            if (_showFallback) ...[
              SizedBox(height: context.r(12)),
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
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.commonCopy,
                      icon: Icon(Icons.copy, size: context.r(18)),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: 'https://${l.addPresentManageUrl}',
                          ),
                        );
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
              OutlinedButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.refresh),
                label: Text(l.commonRetry),
              ),
            ],
            SizedBox(height: context.r(8)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.commonClose),
            ),
          ],
        );
      case _Step.challengeCode:
        final t = Theme.of(context).extension<AvaTokens>()!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The point of no return — say so before the input, not after.
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
                  Icon(
                    Icons.warning_amber_rounded,
                    color: t.warn,
                    size: context.r(20),
                  ),
                  SizedBox(width: context.r(10)),
                  Expanded(
                    child: Text(
                      l.addMoveInWarn,
                      style: TextStyle(color: t.text),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.r(16)),
            Text(l.addMoveInCodePrompt),
            SizedBox(height: context.r(8)),
            TextField(
              controller: _challenge,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (_message != null) ...[
              SizedBox(height: context.r(8)),
              Text(_message!, style: TextStyle(color: t.warn)),
            ],
            SizedBox(height: context.r(16)),
            FilledButton(
              onPressed: _busy ? null : _moveInSubmit,
              child: Text(l.addMoveInConfirm),
            ),
            SizedBox(height: context.r(8)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _message = null;
                      _step = _Step.present;
                    }),
              child: Text(l.commonCancel),
            ),
          ],
        );
      case _Step.failed:
        // Move-in saved nowhere: the text on screen is the only copy of the
        // account's new secret, so it must be selectable, copyable, and must
        // not sit behind a "Close" the user can reflexively tap.
        final fatal = _fatalSecrets;
        if (fatal != null) {
          final body = l.addMoveInSaveFailed(fatal.code, fatal.secret);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.report_problem_outlined,
                size: context.r(48),
                color: Colors.redAccent,
              ),
              SizedBox(height: context.r(12)),
              SelectableText(
                body,
                style: TextStyle(color: Colors.redAccent.shade100),
              ),
              SizedBox(height: context.r(16)),
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: body));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.addMoveInCopied)));
                },
                label: Text(l.addMoveInCopySecrets),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: context.r(48),
              color: Colors.redAccent,
            ),
            SizedBox(height: context.r(12)),
            Text(
              '${l.commonError}: ${_message ?? ''}',
              textAlign: TextAlign.center,
            ),
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
