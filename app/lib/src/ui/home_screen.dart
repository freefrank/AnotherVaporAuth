import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../core/models/steam_guard_account.dart';
import '../core/steam_totp.dart';
import '../services/steam_time.dart';
import 'approve_login_screen.dart';
import 'confirmations_screen.dart';
import 'import_helper.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(appControllerProvider).valueOrNull;
    final accounts = data?.accounts ?? const <SteamGuardAccount>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            tooltip: l.navSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.accountsEmpty, textAlign: TextAlign.center),
            ))
          : ReorderableListView.builder(
              itemCount: accounts.length,
              onReorderItem: (o, n) =>
                  ref.read(appControllerProvider.notifier).reorder(o, n),
              itemBuilder: (context, i) => _AccountTile(
                key: ValueKey(accounts[i].steamId),
                account: accounts[i],
              ),
            ),
      floatingActionButton: _HomeFab(),
    );
  }
}

class _HomeFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const FloatingActionButton(onPressed: null, child: Icon(Icons.add)),
      onSelected: (value) async {
        switch (value) {
          case 'import':
            await importMaFileFlow(context, ref);
            break;
          case 'login':
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LoginScreen(reason: LoginReason.add)));
            break;
          case 'approve':
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ApproveLoginScreen()));
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'import', child: Text(l.actionImport)),
        PopupMenuItem(value: 'login', child: Text(l.actionAddAuthenticator)),
        PopupMenuItem(value: 'approve', child: Text(l.approveTitle)),
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final SteamGuardAccount account;
  const _AccountTile({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tick = ref.watch(tickProvider).valueOrNull ??
        SteamTime.currentSteamTime;

    String code;
    try {
      code = account.generateCode(tick);
    } catch (_) {
      code = '—————';
    }
    final remaining = SteamTotp.secondsRemaining(tick);

    return ListTile(
      title: Text(
        code,
        style: const TextStyle(
          fontSize: 28,
          fontFeatures: [FontFeature.tabularFigures()],
          letterSpacing: 4,
        ),
      ),
      subtitle: Text(account.accountName ?? '${account.steamId}'),
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(value: remaining / 30, strokeWidth: 3),
            Text('$remaining', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _onAction(context, ref, value),
        itemBuilder: (context) => [
          PopupMenuItem(value: 'copy', child: Text(l.copyCode)),
          PopupMenuItem(value: 'confirm', child: Text(l.actionConfirmations)),
          PopupMenuItem(value: 'login', child: Text(l.actionLogin)),
          PopupMenuItem(value: 'remove', child: Text(l.actionRemove)),
        ],
      ),
      onTap: () => _copy(context, ref, code),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String value) async {
    final l = AppLocalizations.of(context);
    switch (value) {
      case 'copy':
        final tick = ref.read(tickProvider).valueOrNull ??
            SteamTime.currentSteamTime;
        _copy(context, ref, account.generateCode(tick));
        break;
      case 'confirm':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConfirmationsScreen(account: account)));
        break;
      case 'login':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LoginScreen(
                reason: LoginReason.refresh, account: account)));
        break;
      case 'remove':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l.removeConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.commonCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.actionRemove)),
            ],
          ),
        );
        if (ok == true) {
          await ref
              .read(appControllerProvider.notifier)
              .removeAccount(account);
        }
        break;
    }
  }

  void _copy(BuildContext context, WidgetRef ref, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).codeCopied)),
    );
  }
}
