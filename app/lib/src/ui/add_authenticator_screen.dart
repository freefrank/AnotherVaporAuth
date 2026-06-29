import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../core/models/session_data.dart';
import '../core/protocol/authenticator_linker.dart';

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
          _failWith('This account already has an authenticator.');
          break;
        case LinkResult.mustConfirmEmail:
          _failWith('Please confirm the email Steam sent, then retry.');
          break;
        case LinkResult.generalFailure:
          _failWith('Failed to add authenticator.');
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
          _message = 'Bad SMS code, try again.';
        });
      } else {
        _failWith('Finalize failed: $result');
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.addAuthTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildStep(l),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.amber.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l.addAuthRevocationWarn(_message ?? '')),
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
