import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/qr_approval_client.dart';
import '../services/session_manager.dart';

/// Polls [account]'s pending login sessions (GetAuthSessionsForAccount) and, for
/// each, shows an approve/deny dialog like the official app — no push needed.
///
/// When [silent] is true (auto-check on open) nothing is shown if there are no
/// pending logins or the session isn't ready; when false (manual) it reports.
Future<void> checkPendingLogins(
  BuildContext context,
  WidgetRef ref,
  SteamGuardAccount account, {
  bool silent = false,
}) async {
  final l = AppLocalizations.of(context);
  void toast(String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  if ((account.session.accessToken ?? '').isEmpty) {
    if (!silent) toast(l.loginNeedSession);
    return;
  }

  final client = QrApprovalClient(ref.read(apiClientProvider));

  Future<List<int>?> fetch() async {
    try {
      return await client.pendingLoginClientIds(account);
    } catch (_) {
      // Stale session — refresh once and retry.
      final refreshed = await SessionManager(ref.read(apiClientProvider))
          .refresh(account.session);
      if (!refreshed) return null;
      try {
        return await client.pendingLoginClientIds(account);
      } catch (_) {
        return null;
      }
    }
  }

  final ids = await fetch();
  if (ids == null) {
    if (!silent) toast(l.loginNeedSession);
    return;
  }
  if (ids.isEmpty) {
    if (!silent) toast(l.loginNoPending);
    return;
  }

  for (final id in ids) {
    if (!context.mounted) return;
    final info = await client.sessionInfo(account, id);
    if (info == null || !context.mounted) continue;
    final approve = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.loginRequestTitle),
        content: Text(l.loginRequestBody(
          info.deviceName.isEmpty ? 'Steam' : info.deviceName,
          info.location.isEmpty ? info.ip : info.location,
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.loginRequestDeny)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.loginRequestApprove)),
        ],
      ),
    );
    if (approve == null) continue; // dismissed — leave it pending
    final ok = await client.respondToSession(account,
        version: info.version, clientId: id, approve: approve);
    if (ok) toast(approve ? l.loginApproved : l.loginDenied);
  }
}
