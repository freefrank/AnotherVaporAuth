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
import 'widgets/motion.dart';
import 'widgets/scanline_overlay.dart';
import 'approve_login_screen.dart';
import 'confirmations_screen.dart';
import 'import_helper.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

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

Color _avatarColor(SteamGuardAccount a) =>
    _palette[a.steamId.hashCode.abs() % _palette.length];

String _codeFor(SteamGuardAccount a, int tick) {
  try {
    return a.generateCode(tick);
  } catch (_) {
    return '—————';
  }
}

/// Main screen — design screen 01, Variant A: a sidebar account list (each row
/// shows its own live code) + a main panel for the selected account (avatar,
/// big code, countdown ring + copy). Responsive: side-by-side on wide screens,
/// stacked (panel on top, list below) on phones.
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
        child: !hasAccounts
            ? _EmptyState(onAdd: () => _addMenu(context))
            : LayoutBuilder(
                builder: (context, c) {
                  final sidebar = _Sidebar(
                    accounts: accounts,
                    selected: _selected,
                    tick: tick,
                    onSelect: (i) => setState(() => _selected = i),
                    onAdd: () => _addMenu(context),
                  );
                  final panel = _MainPanel(
                    account: accounts[_selected],
                    tick: tick,
                    onCopy: _copy,
                  );
                  if (c.maxWidth >= 640) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 240, child: sidebar),
                        Expanded(child: panel),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      panel,
                      const Divider(height: 1),
                      Expanded(child: sidebar),
                    ],
                  );
                },
              ),
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
          await ref.read(appControllerProvider.notifier).removeAccount(account);
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

/// Left/bottom account list. Each row shows the account's own live code.
class _Sidebar extends StatelessWidget {
  final List<SteamGuardAccount> accounts;
  final int selected;
  final int tick;
  final void Function(int index) onSelect;
  final VoidCallback onAdd;
  const _Sidebar({
    required this.accounts,
    required this.selected,
    required this.tick,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(right: BorderSide(color: t.line, width: t.borderWidth)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.navAccounts,
                    style: TextStyle(
                        color: t.muted, fontSize: 11, letterSpacing: 1),
                  ),
                ),
                InkWell(
                  onTap: onAdd,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: t.border,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                    child: Icon(Icons.add, size: 16, color: t.accent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: accounts.length,
              itemBuilder: (context, i) => _SidebarRow(
                account: accounts[i],
                code: _codeFor(accounts[i], tick),
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final SteamGuardAccount account;
  final String code;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarRow({
    required this.account,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? t.panel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: Border(
            left: BorderSide(
              color: selected ? t.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            _Avatar(account: account, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.accountName ?? '${account.steamId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.text, fontSize: 13.5),
                  ),
                  Text(
                    code,
                    style: TextStyle(
                      color: t.accent,
                      fontSize: 13,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main panel for the selected account.
class _MainPanel extends StatelessWidget {
  final SteamGuardAccount account;
  final int tick;
  final void Function(String code) onCopy;
  const _MainPanel(
      {required this.account, required this.tick, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final code = _codeFor(account, tick);
    final remaining = SteamTotp.secondsRemaining(tick);

    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(account: account, size: 34),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.accountName ?? '${account.steamId}',
                      style: TextStyle(color: t.text, fontSize: 14)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulsingDot(color: t.good, size: 7),
                      const SizedBox(width: 6),
                      Text(l.accountReady,
                          style: TextStyle(color: t.muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          FlipCode(code: code, fontSize: t.codeSize, letterSpacing: 8),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CountdownRing(remaining: remaining, size: 74, stroke: 6),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: () => onCopy(code),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l.copyCode),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final SteamGuardAccount account;
  final double size;
  const _Avatar({required this.account, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarColor(account),
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      child: Text(
        _initial(account),
        style: TextStyle(
          color: const Color(0xFF06060F),
          fontSize: size * 0.36,
          fontWeight: FontWeight.bold,
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
