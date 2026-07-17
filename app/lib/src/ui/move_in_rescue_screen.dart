import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';

/// Root-level fallback for a moved-in authenticator whose local save failed.
/// The old authenticator is already dead and [secrets] are the only copies of
/// the new one — this screen replaces the whole app root (see _Root) until the
/// user explicitly confirms they saved them, so an unmounted
/// AddAuthenticatorScreen can no longer take the secrets down with it.
class MoveInRescueScreen extends ConsumerWidget {
  final ({String code, String secret}) secrets;
  const MoveInRescueScreen({super.key, required this.secrets});

  Future<void> _confirmDismiss(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.moveInRescueDismissTitle),
        content: Text(l.moveInRescueDismissBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.bad,
              foregroundColor: const Color(0xFF06060F),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.moveInRescueDismissConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(moveInRescueProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    // Same rules as AddAuthenticatorScreen's fatal step: the text on screen is
    // the only copy of the account's new secret, so it must be selectable,
    // copyable, and never sit behind a reflexively-tappable "Close".
    final body = l.addMoveInSaveFailed(secrets.code, secrets.secret);
    // This screen is the root route: a system back would finish the activity
    // and take the memory-only secrets with it. Leaving is only possible via
    // the same confirmed dismiss the button uses (which clears the provider).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDismiss(context, ref);
      },
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: context.rInsets(all: 24),
              child: Column(
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
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.addMoveInCopied)),
                      );
                    },
                    label: Text(l.addMoveInCopySecrets),
                  ),
                  SizedBox(height: context.r(16)),
                  TextButton(
                    onPressed: () => _confirmDismiss(context, ref),
                    child: Text(
                      l.moveInRescueDismiss,
                      style: TextStyle(
                        color: t.muted,
                        fontSize: context.r(12.5),
                      ),
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
}
