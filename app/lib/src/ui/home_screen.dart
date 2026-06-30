import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
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
import 'pending_login.dart';
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
  bool _checkedLogins = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accounts =
        ref.watch(appControllerProvider).value?.accounts ??
            const <SteamGuardAccount>[];
    final tick =
        ref.watch(tickProvider).value ?? SteamTime.currentSteamTime;
    if (_selected >= accounts.length) _selected = 0;
    final hasAccounts = accounts.isNotEmpty;

    // Auto-check the selected account for pending sign-in requests once on open.
    if (hasAccounts && !_checkedLogins) {
      _checkedLogins = true;
      final acc = accounts[_selected];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) checkPendingLogins(context, ref, acc, silent: true);
      });
    }

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
                PopupMenuItem(
                    value: 'logins', child: Text(l.actionLoginRequests)),
                PopupMenuItem(value: 'login', child: Text(l.actionLogin)),
                PopupMenuItem(value: 'export', child: Text(l.actionExport)),
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
                    wide: c.maxWidth >= 640,
                  );
                  if (c.maxWidth >= 640) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: context.r(240), child: sidebar),
                        Expanded(child: panel),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      panel,
                      Divider(height: context.r(1)),
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
      case 'export':
        await exportMaFileFlow(context, account);
        break;
      case 'logins':
        await checkPendingLogins(context, ref, account);
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
            padding: context.rInsets(left: 14, top: 12, right: 10, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.navAccounts,
                    style: TextStyle(
                        color: t.muted,
                        fontSize: context.r(11),
                        letterSpacing: context.r(1)),
                  ),
                ),
                InkWell(
                  onTap: onAdd,
                  child: Container(
                    width: context.r(24),
                    height: context.r(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: t.border,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                    child: Icon(Icons.add, size: context.r(16), color: t.accent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: context.rInsets(h: 8, v: 4),
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
        margin: context.rInsets(bottom: 6),
        padding: context.rInsets(all: 8),
        decoration: BoxDecoration(
          color: selected ? t.panel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: Border(
            left: BorderSide(
              color: selected ? t.accent : Colors.transparent,
              width: context.r(2),
            ),
          ),
        ),
        child: Row(
          children: [
            _Avatar(account: account, size: context.r(30)),
            SizedBox(width: context.r(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.accountName ?? '${account.steamId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.text, fontSize: context.r(13.5)),
                  ),
                  Text(
                    code,
                    style: TextStyle(
                      color: t.accent,
                      fontSize: context.r(13),
                      letterSpacing: context.r(3),
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
  final bool wide; // two-pane (tablet/desktop) layout
  const _MainPanel(
      {required this.account,
      required this.tick,
      required this.onCopy,
      this.wide = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final code = _codeFor(account, tick);
    final remaining = SteamTotp.secondsRemaining(tick);

    return Padding(
      padding: context.rInsets(all: 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(account: account, size: context.r(34)),
              SizedBox(width: context.r(10)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.accountName ?? '${account.steamId}',
                      style: TextStyle(color: t.text, fontSize: context.r(14))),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulsingDot(color: t.good, size: context.r(7)),
                      SizedBox(width: context.r(6)),
                      Text(l.accountReady,
                          style:
                              TextStyle(color: t.muted, fontSize: context.r(12))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.r(22)),
          // Phone: scale the code to ~66% of the panel width (relative). Tablet /
          // two-pane: keep the v0.56 fixed code size so the wide layout matches
          // the design the user signed off on.
          if (wide)
            FlipCode(code: code, fontSize: t.codeSize)
          else
            LayoutBuilder(
              builder: (context, c) => SizedBox(
                width: (c.maxWidth * 0.66).clamp(140.0, 280.0),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: FlipCode(code: code, fontSize: 56),
                ),
              ),
            ),
          SizedBox(height: context.r(24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CountdownRing(
                  remaining: remaining,
                  size: context.r(74),
                  stroke: context.r(6)),
              SizedBox(width: context.r(20)),
              Flexible(
                child: FilledButton.icon(
                  onPressed: () => onCopy(code),
                  icon: Icon(Icons.copy, size: context.r(16)),
                  label: Text(l.copyCode, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    padding: context.rInsets(h: 22, v: 14),
                  ),
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
    final radius = BorderRadius.circular(t.radiusSm);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarColor(account),
        borderRadius: radius,
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
    final url = account.avatarUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : fallback,
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
        padding: context.rInsets(all: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.accountsEmpty, textAlign: TextAlign.center),
            SizedBox(height: context.r(16)),
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
