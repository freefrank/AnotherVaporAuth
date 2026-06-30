import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/steam_totp.dart';
import '../services/steam_time.dart';
import 'widgets/countdown_ring.dart';
import 'widgets/flip_code.dart';
import 'widgets/scanline_overlay.dart';
import 'approve_login_screen.dart';
import 'confirmations_screen.dart';
import 'import_helper.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Avatar accent palette for the account dock tiles.
const _palette = [
  Color(0xFF00F0FF),
  Color(0xFFFF2BD6),
  Color(0xFF36F0A0),
  Color(0xFFFFD23B),
  Color(0xFFFF8A3D),
  Color(0xFF43C8FF),
];

String _initial(SteamGuardAccount a) {
  final n = (a.accountName ?? '').trim();
  return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
}

/// Main screen — design screen 01, Variant B: a centred big countdown ring +
/// large code + account name + copy, with a bottom account-switcher dock.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accounts =
        ref.watch(appControllerProvider).valueOrNull?.accounts ??
            const <SteamGuardAccount>[];
    final tick =
        ref.watch(tickProvider).valueOrNull ?? SteamTime.currentSteamTime;

    if (_selected >= accounts.length) _selected = 0;
    final hasAccounts = accounts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          if (hasAccounts)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) => _onAction(context, accounts[_selected], v),
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'confirm', child: Text(l.actionConfirmations)),
                PopupMenuItem(value: 'login', child: Text(l.actionLogin)),
                PopupMenuItem(value: 'remove', child: Text(l.actionRemove)),
              ],
            ),
          IconButton(
            tooltip: l.navSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ScanlineOverlay(
        child: hasAccounts
            ? _FocusedView(
                account: accounts[_selected],
                tick: tick,
                onCopy: _copy,
                dock: _AccountDock(
                  accounts: accounts,
                  selected: _selected,
                  onSelect: (i) => setState(() => _selected = i),
                  onAdd: () => _addMenu(context),
                ),
              )
            : _EmptyState(onAdd: () => _addMenu(context)),
      ),
    );
  }

  Future<void> _addMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.panel2,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(l.actionImport),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            ListTile(
              leading: const Icon(Icons.add_moderator_outlined),
              title: Text(l.actionAddAuthenticator),
              onTap: () => Navigator.pop(ctx, 'login'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(l.approveTitle),
              onTap: () => Navigator.pop(ctx, 'approve'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || value == null) return;
    switch (value) {
      case 'import':
        await importMaFileFlow(context, ref);
        break;
      case 'login':
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LoginScreen(reason: LoginReason.add)));
        break;
      case 'approve':
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ApproveLoginScreen()));
        break;
    }
  }

  Future<void> _onAction(
      BuildContext context, SteamGuardAccount account, String value) async {
    final l = AppLocalizations.of(context);
    switch (value) {
      case 'confirm':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConfirmationsScreen(account: account)));
        break;
      case 'login':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                LoginScreen(reason: LoginReason.refresh, account: account)));
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

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).codeCopied)),
    );
  }
}

/// Centred ring + big code + name + copy, with the account dock underneath.
class _FocusedView extends StatelessWidget {
  final SteamGuardAccount account;
  final int tick;
  final void Function(String code) onCopy;
  final Widget dock;

  const _FocusedView({
    required this.account,
    required this.tick,
    required this.onCopy,
    required this.dock,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    String code;
    try {
      code = account.generateCode(tick);
    } catch (_) {
      code = '—————';
    }
    final remaining = SteamTotp.secondsRemaining(tick);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CountdownRing(remaining: remaining, size: 150, stroke: 8),
            const SizedBox(height: 24),
            FlipCode(
              code: code,
              fontSize: t.isPixel ? 38 : 42,
              letterSpacing: 8,
            ),
            const SizedBox(height: 14),
            Text(
              account.accountName ?? '${account.steamId}',
              style: TextStyle(color: t.text, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text('${account.steamId}',
                style: TextStyle(color: t.muted, fontSize: 12)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => onCopy(code),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l.copyCode),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              ),
            ),
            const SizedBox(height: 34),
            dock,
          ],
        ),
      ),
    );
  }
}

/// Bottom dock of account tiles + an add button.
class _AccountDock extends StatelessWidget {
  final List<SteamGuardAccount> accounts;
  final int selected;
  final void Function(int index) onSelect;
  final VoidCallback onAdd;
  const _AccountDock({
    required this.accounts,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < accounts.length; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: _Avatar(
              account: accounts[i],
              size: 46,
              dimmed: i != selected,
              selected: i == selected,
            ),
          ),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: t.line, width: t.borderWidth),
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Icon(Icons.add, color: t.muted),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final SteamGuardAccount account;
  final double size;
  final bool dimmed;
  final bool selected;
  const _Avatar({
    required this.account,
    required this.size,
    this.dimmed = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final color = _palette[account.steamId.hashCode.abs() % _palette.length];
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: selected ? Border.all(color: t.accent, width: 2) : null,
          boxShadow: selected ? t.glowShadow(blur: 12) : null,
        ),
        child: Text(
          _initial(account),
          style: TextStyle(
            color: const Color(0xFF06060F),
            fontSize: size * 0.32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.accountsEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l.actionImport),
            ),
          ],
        ),
      ),
    );
  }
}
