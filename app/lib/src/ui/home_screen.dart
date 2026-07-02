import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/steam_totp.dart';
import '../services/steam_time.dart';
import 'widgets/animated_steam_image.dart';
import 'widgets/app_logo.dart';
import 'widgets/countdown_ring.dart';
import 'widgets/cyber_ambient.dart';
import 'widgets/flip_code.dart';
import 'widgets/motion.dart';
import 'widgets/pixel_ambient.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/steam_image_provider.dart';
import 'approve_login_screen.dart';
import 'confirmations_screen.dart';
import 'import_helper.dart';
import 'pending_login.dart';
import 'login_screen.dart';
import 'market/market_screen.dart';
import 'settings_screen.dart';
import 'tutorial.dart';

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

/// How an account's primary label is shown — tapping the panel name cycles it.
enum _NameMode { username, persona, id }

String _displayName(SteamGuardAccount a, _NameMode mode) {
  switch (mode) {
    case _NameMode.username:
      return a.accountName ?? '${a.steamId}';
    case _NameMode.persona:
      final p = a.personaName;
      return (p != null && p.isNotEmpty) ? p : (a.accountName ?? '${a.steamId}');
    case _NameMode.id:
      return '${a.steamId}';
  }
}

/// Fade + scale + full-height vertical slide used when an account label changes
/// (mode toggle or switching the selected account) — deliberately pronounced.
Widget _nameTransition(Widget child, Animation<double> anim) {
  final slide = Tween(begin: const Offset(0, 1.0), end: Offset.zero)
      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: slide,
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(anim),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    ),
  );
}

/// An account label that animates whenever its text changes.
class _AnimatedName extends StatelessWidget {
  final SteamGuardAccount account;
  final _NameMode mode;
  final TextStyle style;
  const _AnimatedName(
      {required this.account, required this.mode, required this.style});

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": plain crossfade instead of slide + scale.
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce ? 150 : 420),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: reduce
          ? (child, anim) => FadeTransition(opacity: anim, child: child)
          : _nameTransition,
      // Clip so the full-height slide doesn't bleed into neighbours.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        children: [...previous, ?current],
      ),
      child: Text(
        _displayName(account, mode),
        key: ValueKey('${account.steamId}-${mode.index}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _selected = 0;
  bool _checkedLogins = false;
  bool _checkedTutorial = false;
  int _lastTutorialReplay = 0;
  _NameMode _nameMode = _NameMode.username;

  // First-run gesture tutorial hooks: spotlight targets + a controller that
  // lets the tutorial physically open the first row's swipe panes. The targets
  // are LayerLinks so the spotlight follows the real painted position of the
  // code / first row across every layout (phone, tablet two-pane, foldable) —
  // the compositing layer handles the transform, no manual coordinate math.
  final _codeLink = LayerLink();
  final _firstRowLink = LayerLink();
  late final _demoSlidable = SlidableController(this);

  // Custom neon pull-to-refresh state.
  double _pull = 0; // px pulled beyond the top
  bool _refreshing = false;
  // Whether the running refresh should drive the full-screen pull overlay
  // (true for the pull gesture, false for the desktop refresh button).
  bool _pullVisual = false;
  static const double _pullThreshold = 130;

  @override
  void dispose() {
    _demoSlidable.dispose();
    super.dispose();
  }

  /// Shows the gesture tutorial once, on touch platforms only (desktop users
  /// get a right-click context menu on the rows instead).
  void _maybeShowTutorial() {
    if (_checkedTutorial) return;
    _checkedTutorial = true;
    final platform = Theme.of(context).platform;
    final touch = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
    if (!touch) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Only over the home screen itself — the first account may appear while
      // a login/finalize screen is still on top (revocation code!). Re-arm and
      // retry on a later build (the 1s tick rebuilds us) once we're current.
      if (ModalRoute.of(context)?.isCurrent != true) {
        _checkedTutorial = false;
        return;
      }
      final store = ref.read(settingsStoreProvider);
      if (await store.loadTutorialSeen() || !mounted) return;
      await showGestureTutorial(
        context,
        codeLink: _codeLink,
        firstRowLink: _firstRowLink,
        slidable: _demoSlidable,
      );
      await store.saveTutorialSeen();
    });
  }

  void _cycleNameMode() => setState(() {
        _nameMode =
            _NameMode.values[(_nameMode.index + 1) % _NameMode.values.length];
      });

  void _onPullPixels(double overscroll) {
    if (_refreshing) return;
    final p = overscroll.clamp(0.0, _pullThreshold * 1.5);
    if (p == _pull) return;
    // Haptic "click" the moment the pull charges past the trigger threshold.
    if (_pull < _pullThreshold && p >= _pullThreshold) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _pull = p);
  }

  void _onPullEnd() {
    if (_refreshing) return;
    if (_pull >= _pullThreshold) {
      _startRefresh();
    } else if (_pull != 0) {
      setState(() => _pull = 0);
    }
  }

  /// Refreshes avatars/frames and polls the selected account's sign-ins. Shared
  /// by the neon pull overlay and the pixel-theme RefreshIndicator.
  Future<void> _runRefresh() async {
    final accounts =
        ref.read(appControllerProvider).value?.accounts ?? const [];
    await ref.read(appControllerProvider.notifier).refreshAvatars();
    if (mounted && accounts.isNotEmpty) {
      await checkPendingLogins(context, ref, accounts[_selected],
          silent: false);
    }
  }

  Future<void> _startRefresh({bool visual = true}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _pullVisual = visual;
    });
    try {
      await _runRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullVisual = false;
          _pull = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The cyberpunk ambience / neon pull / glow borders are neon-theme only.
    final neon = !(Theme.of(context).extension<SdaTokens>()?.isPixel ?? false);
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
    // Settings → "replay tutorial" bumps the counter; re-arm the walkthrough.
    final replay = ref.watch(tutorialReplayProvider);
    if (replay != _lastTutorialReplay) {
      _lastTutorialReplay = replay;
      _checkedTutorial = false;
    }
    if (hasAccounts) _maybeShowTutorial();

    return Scaffold(
      // Header removed — settings is a floating button in the bottom-right.
      floatingActionButton: _SettingsFab(
        label: l.navSettings,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      body: ScanlineOverlay(
        child: !hasAccounts
            ? Stack(
                children: [
                  Positioned.fill(
                      child: neon
                          ? const CyberAmbient()
                          : const PixelAmbient()),
                  SafeArea(child: _EmptyState(onAdd: () => _addMenu(context))),
                ],
              )
            : LayoutBuilder(
                builder: (context, c) {
                  final sidebar = _Sidebar(
                    accounts: accounts,
                    selected: _selected,
                    tick: tick,
                    onSelect: (i) {
                      setState(() => _selected = i);
                      // Tapping an account polls its pending sign-in requests.
                      checkPendingLogins(context, ref, accounts[i],
                          silent: true);
                    },
                    onAdd: () => _addMenu(context),
                    nameMode: _nameMode,
                    neon: neon,
                    // Per-account swipe actions (the old overflow menu).
                    onAction: (acc, action) => _onAction(context, acc, action),
                    // Custom pull drives the full-screen overlay below (neon fill
                    // or pixel blocks).
                    onPullPixels: _onPullPixels,
                    onPullEnd: _onPullEnd,
                    // Desktop has no touch pull-to-refresh — the sidebar shows
                    // a refresh button there instead (no full-screen overlay).
                    onRefresh: () => _startRefresh(visual: false),
                    refreshing: _refreshing,
                    firstRowLink: _firstRowLink,
                    demoSlidable: _demoSlidable,
                  );
                  final panel = _MainPanel(
                    account: accounts[_selected],
                    tick: tick,
                    onCopy: _copy,
                    wide: c.maxWidth >= 640,
                    nameMode: _nameMode,
                    onTapName: _cycleNameMode,
                    codeLink: _codeLink,
                  );
                  final Widget content = SafeArea(
                    bottom: false,
                    child: c.maxWidth >= 640
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: context.r(240), child: sidebar),
                              Expanded(child: panel),
                            ],
                          )
                        : Column(
                            children: [
                              panel,
                              Divider(height: context.r(1)),
                              Expanded(child: sidebar),
                            ],
                          ),
                  );
                  final pull01 = _refreshing && _pullVisual
                      ? 1.0
                      : (_pull / _pullThreshold).clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      // Cyberpunk ambience / HUD / neon pull — neon theme only.
                      if (neon) ...[
                        const Positioned.fill(child: CyberAmbient()),
                        content,
                        const Positioned.fill(child: CyberHud()),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: pull01),
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              builder: (_, v, _) => v <= 0.001
                                  ? const SizedBox.shrink()
                                  : _NeonPull(progress: v),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Pixel theme: retro backdrop + blocky pull indicator.
                        const Positioned.fill(child: PixelAmbient()),
                        content,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: pull01),
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              builder: (_, v, _) => v <= 0.001
                                  ? const SizedBox.shrink()
                                  : _PixelPull(progress: v),
                            ),
                          ),
                        ),
                      ],
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

    // Themed floating sheet (neon: glowing rounded panel / pixel: hard-edged
    // sticker) instead of the stock M3 list.
    Widget row(BuildContext ctx, IconData icon, String label, String result) =>
        InkWell(
          onTap: () => Navigator.pop(ctx, result),
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: Padding(
            padding: context.rInsets(h: 16, v: 11),
            child: Row(
              children: [
                Container(
                  width: context.r(36),
                  height: context.r(36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.55),
                        width: t.borderWidth),
                  ),
                  child: Icon(icon, color: t.accent, size: context.r(18)),
                ),
                SizedBox(width: context.r(14)),
                Text(label,
                    style:
                        TextStyle(color: t.text, fontSize: context.r(14.5))),
              ],
            ),
          ),
        );

    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: context.rInsets(h: 10, bottom: 10),
          padding: context.rInsets(v: 8),
          decoration: BoxDecoration(
            // Nearly opaque so the list doesn't ghost through the neon glass.
            color: t.isPixel ? t.panel2 : t.panel2.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(t.isPixel ? 0 : t.radius),
            border: Border.all(
              color: t.isPixel
                  ? t.borderColor
                  : t.accent.withValues(alpha: 0.5),
              width: t.borderWidth,
            ),
            boxShadow: t.isPixel
                ? t.cardShadow()
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10)),
                    ...t.glowShadow(blur: context.r(18), opacity: 0.18),
                  ],
          ),
          // Transparent Material above the opaque panel so the row ink
          // ripples actually show.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: context.rInsets(top: 2, bottom: 6),
                    width: context.r(40),
                    height: context.r(4),
                    decoration: BoxDecoration(
                      color: t.line,
                      borderRadius:
                          BorderRadius.circular(t.isPixel ? 0 : context.r(2)),
                    ),
                  ),
                ),
                row(ctx, Icons.file_open_outlined, l.actionImport, 'import'),
                row(ctx, Icons.add_moderator_outlined,
                    l.actionAddAuthenticator, 'login'),
                row(ctx, Icons.qr_code_scanner, l.approveTitle, 'approve'),
              ],
            ),
          ),
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
      case 'market':
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MarketScreen(account: account)));
        break;
      case 'remove':
        final t = Theme.of(context).extension<SdaTokens>()!;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l.removeConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.commonCancel)),
              // Destructive action — red, visually separated from the accent.
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: t.bad,
                      foregroundColor: const Color(0xFF06060F)),
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
  final void Function(double overscroll) onPullPixels;
  final VoidCallback onPullEnd;
  final void Function(SteamGuardAccount account, String action) onAction;
  final _NameMode nameMode;
  final bool neon;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final LayerLink? firstRowLink;
  final SlidableController? demoSlidable;
  const _Sidebar({
    required this.accounts,
    required this.selected,
    required this.tick,
    required this.onSelect,
    required this.onAdd,
    required this.nameMode,
    required this.neon,
    required this.onAction,
    required this.onPullPixels,
    required this.onPullEnd,
    this.onRefresh,
    this.refreshing = false,
    this.firstRowLink,
    this.demoSlidable,
  });

  Widget _list(BuildContext context) => SlidableAutoCloseBehavior(
        child: ListView.builder(
          // Bouncing so the custom pull-to-refresh reads overscroll on both
          // themes (neon fill / pixel blocks).
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          // Bottom clearance so the floating settings button doesn't cover the
          // last row.
          padding: context.rInsets(left: 8, right: 8, top: 4, bottom: 78),
          itemCount: accounts.length,
          itemBuilder: (context, i) {
            final row = _SidebarRow(
              account: accounts[i],
              code: _codeFor(accounts[i], tick),
              selected: i == selected,
              nameMode: nameMode,
              neon: neon,
              onTap: () => onSelect(i),
              onAction: onAction,
              controller: i == 0 ? demoSlidable : null,
            );
            // The first row anchors the tutorial spotlight (+ its swipe demo).
            if (i == 0 && firstRowLink != null) {
              return CompositedTransformTarget(link: firstRowLink!, child: row);
            }
            return row;
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Neon panel is already translucent; make the pixel list translucent too
        // so the starfield backdrop shows through.
        color: neon ? t.panel : t.panel.withValues(alpha: 0.32),
        border: Border(right: BorderSide(color: t.line, width: t.borderWidth)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: context.rInsets(left: 14, right: 10),
            // Fixed 48dp-tall header so the add button gets a full-size touch
            // target; the 24px visual is unchanged.
            child: SizedBox(
              height: context.r(48),
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
                  // Mouse users can't pull-to-refresh — give desktop a button.
                  if (onRefresh != null &&
                      switch (Theme.of(context).platform) {
                        TargetPlatform.linux ||
                        TargetPlatform.macOS ||
                        TargetPlatform.windows =>
                          true,
                        _ => false,
                      })
                    InkWell(
                      onTap: refreshing ? null : onRefresh,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      child: SizedBox(
                        width: context.r(40),
                        height: context.r(48),
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: context.r(24),
                            height: context.r(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: t.border,
                              borderRadius: BorderRadius.circular(t.radiusSm),
                            ),
                            child: refreshing
                                ? SizedBox(
                                    width: context.r(13),
                                    height: context.r(13),
                                    child: const CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(Icons.refresh,
                                    size: context.r(15), color: t.accent),
                          ),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    child: SizedBox(
                      width: context.r(52),
                      height: context.r(48),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: context.r(24),
                          height: context.r(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: t.border,
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                          child: Icon(Icons.add,
                              size: context.r(16), color: t.accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Listener(
              onPointerUp: (_) => onPullEnd(),
              // Trackpads (macOS) scroll via pan-zoom events, not pointer up.
              onPointerPanZoomEnd: (_) => onPullEnd(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  final px = n.metrics.pixels;
                  onPullPixels(px < 0 ? -px : 0);
                  return false;
                },
                child: _list(context),
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
  final _NameMode nameMode;
  final bool neon;
  final VoidCallback onTap;
  final void Function(SteamGuardAccount account, String action) onAction;
  final SlidableController? controller;
  const _SidebarRow({
    required this.account,
    required this.code,
    required this.selected,
    required this.nameMode,
    required this.neon,
    required this.onTap,
    required this.onAction,
    this.controller,
  });

  /// Desktop/mouse path for the swipe + long-press actions: a right-click
  /// context menu with the same entries.
  Future<void> _contextMenu(BuildContext context, Offset at) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    PopupMenuItem<String> item(String value, IconData icon, String label,
            {Color? color}) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18, color: color ?? t.muted),
              const SizedBox(width: 10),
              Text(label, style: color != null ? TextStyle(color: color) : null),
            ],
          ),
        );

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        item('confirm', Icons.verified_user_outlined, l.actionConfirmations),
        item('market', Icons.inventory_2_outlined, l.actionMarket),
        item('login', Icons.refresh, l.commonRefresh),
        item('export', Icons.ios_share, l.commonExport),
        item('remove', Icons.delete_outline, l.commonDelete, color: t.bad),
      ],
    );
    if (action != null && context.mounted) onAction(account, action);
  }

  /// Long-press menu: manage the stored auto-login password.
  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final r = context.r(1);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final neon = t.glow;
    // Neon theme: dark glassy pill + neon border/inset glow (HUD look).
    // Pixel theme: chunky retro button — bright fill, hard 2px border, hard
    // offset shadow, dark text (no blur, radius 0).
    const ink = Color(0xFF15111F);
    final fill = neon ? color.withValues(alpha: 0.16) : color;
    final fg = neon ? color : ink;
    return CustomSlidableAction(
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      onPressed: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        // Extra vertical margin insets the pill so it isn't as tall as the row.
        margin: EdgeInsets.symmetric(
            horizontal: neon ? 3 * r : 4 * r, vertical: 12 * r),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(neon ? t.radiusSm : 0),
          border: neon
              ? Border.all(
                  color: color.withValues(alpha: 0.9), width: t.borderWidth)
              : Border.all(color: ink, width: 2),
          boxShadow: neon
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 5,
                      blurStyle: BlurStyle.inner),
                ]
              : [BoxShadow(color: ink, offset: Offset(3 * r, 3 * r))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 19 * r),
            SizedBox(height: 3 * r),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2 * r),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg,
                      fontSize: 11.5 * r,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final l = AppLocalizations.of(context);
    return Padding(
      padding: context.rInsets(bottom: 8),
      child: Slidable(
        key: ValueKey(account.steamId),
        controller: controller,
        // Swipe RIGHT → enter trade confirmations (full swipe enters directly).
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.34,
          dismissible: DismissiblePane(
            closeOnCancel: true,
            confirmDismiss: () async {
              onAction(account, 'confirm');
              return false; // navigate, don't actually remove the row
            },
            onDismissed: () {},
          ),
          children: [
            _action(context,
                icon: Icons.verified_user_outlined,
                label: l.actionConfirmations,
                color: t.good,
                onTap: () => onAction(account, 'confirm')),
          ],
        ),
        // Swipe LEFT → the other per-account actions.
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.66,
          children: [
            _action(context,
                icon: Icons.refresh,
                label: l.commonRefresh,
                color: t.accent,
                onTap: () => onAction(account, 'login')),
            _action(context,
                icon: Icons.ios_share,
                label: l.commonExport,
                color: t.accent2,
                onTap: () => onAction(account, 'export')),
            _action(context,
                icon: Icons.delete_outline,
                label: l.commonDelete,
                color: t.bad,
                onTap: () => onAction(account, 'remove')),
          ],
        ),
        child: GestureDetector(
          // Mouse right-click mirrors the touch gestures (desktop).
          onSecondaryTapDown: (d) => _contextMenu(context, d.globalPosition),
          child: InkWell(
          onTap: onTap,
          onLongPress: () => onAction(account, 'market'),
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: Container(
            padding: context.rInsets(all: 8),
            decoration: neon
            ? BoxDecoration(
                color:
                    selected ? t.panel2 : t.panel2.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(t.radiusSm),
                // Every account gets a neon frame; the selected one glows.
                border: Border.all(
                  color: selected ? t.accent : t.accent.withValues(alpha: 0.28),
                  width: selected ? context.r(1.6) : context.r(1),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.35),
                          blurRadius: context.r(10),
                          spreadRadius: context.r(0.5),
                        ),
                      ]
                    : null,
              )
            : BoxDecoration(
                // Pixel theme: retro "sticker" — chunky 2px border + a hard
                // offset shadow on the selected row (no blur, radius 0).
                color: selected ? t.panel2 : t.panel.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(t.radiusSm),
                border: Border.all(
                  color: selected ? t.accent : t.line,
                  width: t.borderWidth,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: t.borderColor,
                          offset: Offset(context.r(4), context.r(4)),
                        ),
                      ]
                    : null,
              ),
        child: Row(
          children: [
            _Avatar(account: account, size: context.r(70)),
            SizedBox(width: context.r(15)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AnimatedName(
                      account: account,
                      mode: nameMode,
                      style:
                          TextStyle(color: t.text, fontSize: context.r(19.5)),
                    ),
                  ),
                  Text(
                    code,
                    style: TextStyle(
                      color: t.accent,
                      fontSize: context.r(18),
                      letterSpacing: context.r(3),
                    ),
                  ),
                ],
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

/// Main panel for the selected account.
class _MainPanel extends StatelessWidget {
  final SteamGuardAccount account;
  final int tick;
  final void Function(String code) onCopy;
  final bool wide; // two-pane (tablet/desktop) layout
  final _NameMode nameMode;
  final VoidCallback onTapName;
  final LayerLink? codeLink; // tutorial spotlight anchor
  const _MainPanel(
      {required this.account,
      required this.tick,
      required this.onCopy,
      required this.nameMode,
      required this.onTapName,
      this.codeLink,
      this.wide = false});

  Widget _linkTarget(LayerLink? link, Widget child) =>
      link == null ? child : CompositedTransformTarget(link: link, child: child);

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
              _Avatar(account: account, size: context.r(104)),
              SizedBox(width: context.r(18)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tap to cycle username / persona / id; long-press to copy.
                  GestureDetector(
                    onTap: onTapName,
                    onLongPress: () {
                      final text = _displayName(account, nameMode);
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.copied)),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _AnimatedName(
                              account: account,
                              mode: nameMode,
                              style: TextStyle(
                                  color: t.text, fontSize: context.r(23)),
                            ),
                          ),
                          SizedBox(width: context.r(6)),
                          Icon(Icons.swap_horiz,
                              size: context.r(16), color: t.muted),
                        ],
                      ),
                    ),
                  ),
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
          SizedBox(height: context.r(26)),
          // Code + countdown ring on one row. Tap the code to copy it (the
          // explicit copy button is gone). Phone: scale the code relative to the
          // viewport; tablet / two-pane: keep the fixed design size.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                // The tutorial spotlight follows this via a LayerLink, so it
                // tracks the code's real painted position in every layout.
                child: _linkTarget(
                  codeLink,
                  _TapScale(
                    onTap: () => onCopy(code),
                    child: wide
                        ? FlipCode(code: code, fontSize: t.codeSize)
                        : SizedBox(
                            width: (MediaQuery.sizeOf(context).width * 0.46)
                                .clamp(120.0, 260.0),
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              child: FlipCode(code: code, fontSize: 56),
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(width: context.r(18)),
              CountdownRing(
                  remaining: remaining,
                  size: context.r(wide ? 64 : 70),
                  stroke: context.r(6)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating settings button (bottom-right), styled per theme: neon glass disc
/// with an accent glow, or a chunky pixel square with a hard offset shadow.
class _SettingsFab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SettingsFab({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final neon = t.glow;
    final size = context.r(54);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(neon ? size / 2 : t.radiusSm),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: neon
                ? BoxDecoration(
                    color: t.panel2,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.accent, width: context.r(1.4)),
                    boxShadow: [
                      BoxShadow(
                          color: t.accent.withValues(alpha: 0.4),
                          blurRadius: context.r(14)),
                    ],
                  )
                : BoxDecoration(
                    color: t.panel2,
                    border: Border.all(color: t.accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: t.borderColor,
                          offset: Offset(context.r(3), context.r(3))),
                    ],
                  ),
            child: Icon(Icons.settings_outlined,
                color: t.accent, size: context.r(26)),
          ),
        ),
      ),
    );
  }
}

/// Wraps a tappable child with a subtle press-scale for tactile feedback.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Full-screen animated red/blue neon fill that grows from the top as the user
/// pulls down — moving scanlines, a cyber grid and a pulsing glowing edge, with
/// a white-hot "charged" state once the trigger threshold is reached.
class _NeonPull extends StatefulWidget {
  final double progress; // 0..1
  const _NeonPull({required this.progress});

  @override
  State<_NeonPull> createState() => _NeonPullState();
}

class _NeonPullState extends State<_NeonPull>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": keep the neon fill but freeze the sweeps.
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      if (_ac.isAnimating) _ac.stop();
    } else if (!_ac.isAnimating) {
      _ac.repeat();
    }
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        widthFactor: 1,
        heightFactor: widget.progress.clamp(0.0, 1.0),
        child: AnimatedBuilder(
          animation: _ac,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: _NeonPainter(
              progress: widget.progress,
              t: reduce ? 0 : _ac.value,
              charged: widget.progress >= 0.97,
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final double progress;
  final double t; // 0..1 animation phase
  final bool charged;
  _NeonPainter(
      {required this.progress, required this.t, required this.charged});

  static const _red = Color(0xFFFF1B6B);
  static const _blue = Color(0xFF18E0FF);
  static const _cyan = Color(0xFF00FFFF);
  static const _magenta = Color(0xFFFF2BD6);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

    // Base red↔blue wash, intensifying with the pull.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blue.withValues(alpha: 0.05 + 0.32 * progress),
            _red.withValues(alpha: 0.06 + 0.40 * progress),
          ],
        ).createShader(rect),
    );

    // Faint vertical cyber grid.
    final grid = Paint()
      ..color = _cyan.withValues(alpha: 0.07 * progress)
      ..strokeWidth = 1;
    for (var x = 0.0; x < w; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }

    // Moving neon scanlines sweeping downward.
    const n = 5;
    for (var i = 0; i < n; i++) {
      final y = ((t + i / n) % 1.0) * h;
      final c = i.isEven ? _cyan : _magenta;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = c.withValues(alpha: 0.45 * progress)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = c.withValues(alpha: 0.85 * progress)
          ..strokeWidth = 1.4,
      );
    }

    // Pulsing glowing leading edge at the bottom of the fill.
    final edgeY = h - 2;
    final edgeRect = Rect.fromLTWH(0, edgeY - 3, w, 6);
    final edgeShader =
        const LinearGradient(colors: [_red, _magenta, _blue]).createShader(edgeRect);
    canvas.drawLine(
      Offset(0, edgeY),
      Offset(w, edgeY),
      Paint()
        ..shader = edgeShader
        ..strokeWidth = charged ? 7 : 5
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, (charged ? 22 : 14) * (0.6 + 0.4 * pulse)),
    );
    canvas.drawLine(
      Offset(0, edgeY),
      Offset(w, edgeY),
      Paint()
        ..shader = edgeShader
        ..strokeWidth = charged ? 4 : 2.5,
    );

    // Charged: white-hot flash pulse across the whole fill.
    if (charged) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: 0.05 + 0.10 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_NeonPainter old) =>
      old.t != t || old.progress != progress || old.charged != charged;
}

/// Pixel-theme pull-to-refresh: a blocky retro fill that grows from the top with
/// a chunky pixel leading bar and a blinking "LOADING" once charged.
class _PixelPull extends StatefulWidget {
  final double progress; // 0..1
  const _PixelPull({required this.progress});

  @override
  State<_PixelPull> createState() => _PixelPullState();
}

class _PixelPullState extends State<_PixelPull>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final blinkOn = reduce ? true : _c.value < 0.5;
        final charged = widget.progress >= 0.97;
        return Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: widget.progress.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _PixelPullPainter(
                    color: t.accent,
                    progress: widget.progress,
                    blinkOn: blinkOn,
                  ),
                ),
                if (charged)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Opacity(
                        opacity: blinkOn ? 1 : 0.2,
                        child: Text(
                          '▼ LOADING ▼',
                          style: TextStyle(
                            color: t.accent,
                            fontSize: 13,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PixelPullPainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool blinkOn;
  _PixelPullPainter(
      {required this.color, required this.progress, required this.blinkOn});

  static const double _cell = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Flat blocky wash.
    canvas.drawRect(Offset.zero & size,
        Paint()..color = color.withValues(alpha: 0.08 + 0.12 * progress));
    // Checkerboard pixel texture.
    final tex = Paint()..color = color.withValues(alpha: 0.07);
    for (var y = 0.0, ry = 0; y < h; y += _cell, ry++) {
      for (var x = 0.0, rx = 0; x < w; x += _cell, rx++) {
        if ((rx + ry).isEven) {
          canvas.drawRect(Rect.fromLTWH(x, y, _cell, _cell), tex);
        }
      }
    }
    // Chunky leading bar: two rows of hard pixel blocks at the bottom.
    for (var x = 0.0, rx = 0; x < w; x += _cell, rx++) {
      final lit = blinkOn ? true : rx.isEven; // marching blocks
      canvas.drawRect(
          Rect.fromLTWH(x + 1, h - _cell + 1, _cell - 2, _cell - 2),
          Paint()..color = color.withValues(alpha: lit ? 0.9 : 0.5));
      canvas.drawRect(
          Rect.fromLTWH(x + 1, h - _cell * 2 + 1, _cell - 2, _cell - 2),
          Paint()..color = color.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(_PixelPullPainter old) =>
      old.progress != progress || old.blinkOn != blinkOn;
}

class _Avatar extends StatelessWidget {
  final SteamGuardAccount account;
  final double size;
  const _Avatar({required this.account, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final radius = BorderRadius.circular(t.radiusSm);
    Widget fallback(double d) => Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _avatarColor(account),
            borderRadius: radius,
          ),
          child: Text(
            _initial(account),
            style: TextStyle(
              color: const Color(0xFF06060F),
              fontSize: d * 0.36,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    final url = account.avatarUrl;
    final animUrl = account.animatedAvatarUrl;
    final frameUrl = account.avatarFrameUrl;
    final hasFrame = frameUrl != null && frameUrl.isNotEmpty;
    // With a frame, inset the avatar so the frame's border sits around it.
    final avatarSize = hasFrame ? size * 0.78 : size;
    // Prefer the animated avatar (a GIF, which the engine codec animates
    // natively) and fall back to the static avatar. SteamImageProvider serves
    // bytes from the disk cache, so a relaunch shows avatars instantly; the
    // background profile refresh swaps the URL when the avatar changes.
    final displayUrl =
        (animUrl != null && animUrl.isNotEmpty) ? animUrl : url;
    final Widget avatar = (displayUrl == null || displayUrl.isEmpty)
        ? fallback(avatarSize)
        : ClipRRect(
            borderRadius: radius,
            child: Image(
              // Decode at display size (animated GIFs keep animating), in
              // 32px buckets so desktop window resizes don't re-decode.
              image: ResizeImage.resizeIfNeeded(
                (((avatarSize * MediaQuery.devicePixelRatioOf(context))
                                .ceil() +
                            31) ~/
                        32) *
                    32,
                null,
                SteamImageProvider(displayUrl),
              ),
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback(avatarSize),
              frameBuilder: (ctx, child, frame, syncLoaded) =>
                  (frame == null && !syncLoaded)
                      ? fallback(avatarSize)
                      : child,
            ),
          );
    if (!hasFrame) return avatar;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          // The frame may itself be animated (APNG); contain to fit the box.
          IgnorePointer(
            child: AnimatedSteamImage(
              url: frameUrl,
              size: size,
              fit: BoxFit.contain,
            ),
          ),
        ],
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
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Center(
      child: Padding(
        padding: context.rInsets(all: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingLogo(child: AppLogo(size: context.r(84))),
            SizedBox(height: context.r(22)),
            Text(l.accountsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.muted, height: 1.6)),
            SizedBox(height: context.r(18)),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l.emptyAddAccount),
            ),
          ],
        ),
      ),
    );
  }
}
