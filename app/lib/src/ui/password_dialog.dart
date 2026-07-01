import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../core/models/steam_guard_account.dart';
import '../services/auto_login.dart';

/// Prompts for [account]'s Steam password, verifies it with a real (headless)
/// login, and on success stores it in the keystore and persists the fresh
/// tokens. Returns true if a password was saved.
Future<bool> promptSavePassword(
    BuildContext context, WidgetRef ref, SteamGuardAccount account) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PasswordDialog(account: account, ref: ref),
  );
  return ok ?? false;
}

class _PasswordDialog extends StatefulWidget {
  final SteamGuardAccount account;
  final WidgetRef ref;
  const _PasswordDialog({required this.account, required this.ref});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final pwd = _controller.text;
    if (pwd.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auto = widget.ref.read(autoLoginProvider);
    final outcome = await auto.reloginWithPassword(widget.account, pwd);
    if (!mounted) return;
    if (outcome == AutoLoginOutcome.ok) {
      // Store the password (and the fresh tokens) in the maFile.
      widget.account.password = pwd;
      await widget.ref
          .read(appControllerProvider.notifier)
          .persistAccount(widget.account);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.pwdSaved)));
      return;
    }
    setState(() {
      _busy = false;
      _error = outcome == AutoLoginOutcome.needsInteractive
          ? l.pwdNeedsEmail
          : l.pwdWrong;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.pwdSaveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pwdSaveBody, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l.pwdField,
              errorText: _error,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.pwdVerify),
        ),
      ],
    );
  }
}
