// app/lib/src/ui/device_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/device_session.dart';
import '../core/models/steam_guard_account.dart';
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';

/// Read-only list of the account's logged-in devices / sessions
/// (`IAuthenticationService/EnumerateTokens`). Remote sign-out is not offered
/// yet — see `docs/specs/device-sessions.md` §Revoke.
class DeviceSessionsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const DeviceSessionsScreen({super.key, required this.account});

  @override
  ConsumerState<DeviceSessionsScreen> createState() =>
      _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends ConsumerState<DeviceSessionsScreen>
    with SessionRetryState {
  DeviceSessionList? _list;
  bool _loading = true;
  bool _busy = false; // a revoke is in flight
  String? _error;
  bool _needsLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final client = ref.read(sessionsClientProvider);
      // Auto-refresh the session and retry once on an expired token — same
      // pattern as the family / trade screens.
      final list = await fetchWithAutoRefresh<DeviceSessionList>(
          widget.account, () => client.enumerate(widget.account));
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final needsLogin = isAuthError(e);
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _needsLogin = needsLogin;
        _error = needsLogin ? l.confNeedsLogin : fetchErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.deviceSessionsTitle),
        actions: [
          IconButton(
            tooltip: l.confirmationsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ScanlineOverlay(child: _body(l, t)),
    );
  }

  Widget _body(AppLocalizations l, AvaTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: sessionErrorBody(
          l,
          t,
          error: _error!,
          needsLogin: _needsLogin,
          onSignIn: () => signInThen(widget.account, _load),
          onRetry: _load,
        ),
      );
    }
    final list = _list!;
    if (list.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: context.rInsets(all: 24),
          child: Text(l.deviceSessionsEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: context.rSafeInsets(all: 16),
      children: [
        for (final d in list.devices)
          Padding(
            padding: context.rInsets(bottom: 8),
            child: _deviceCard(l, t, d, list.isCurrent(d)),
          ),
      ],
    );
  }

  /// Confirms, then remotely signs [d] out and refreshes. Never called for the
  /// current device (the card hides revoke for it — self-revoke would sign the
  /// app out of the account).
  Future<void> _revoke(AppLocalizations l, AvaTokens t, DeviceSession d) async {
    if (_busy) return;
    final name = d.description.isNotEmpty ? d.description : l.deviceUnnamed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.deviceRevokeConfirm(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: t.bad,
                foregroundColor: const Color(0xFF06060F)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deviceRevokeAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await fetchWithAutoRefresh<void>(
          widget.account, () => ref.read(sessionsClientProvider).revoke(
                widget.account,
                d,
              ));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.deviceRevokeDone(name))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text(l.deviceRevokeFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _deviceCard(
      AppLocalizations l, AvaTokens t, DeviceSession d, bool current) {
    final name = d.description.isNotEmpty ? d.description : l.deviceUnnamed;
    final loc = d.lastSeen?.locationLabel ?? '';
    final age = _age(l, d.timeUpdated);
    final sub = [
      _platformLabel(l, d.platformType),
      if (loc.isNotEmpty) loc,
      if (age.isNotEmpty) l.deviceLastSeen(age),
    ].join(' · ');
    return AvaPanel(
      padding: context.rInsets(all: 12),
      child: Row(
        children: [
          Icon(_platformIcon(d.platformType),
              size: context.r(20), color: current ? t.accent : t.muted),
          SizedBox(width: context.r(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text, fontSize: context.r(13))),
                    ),
                    if (current) ...[
                      SizedBox(width: context.r(6)),
                      Text(l.deviceCurrent,
                          style: TextStyle(
                              color: t.accent, fontSize: context.r(11))),
                    ],
                    if (!d.loggedIn) ...[
                      SizedBox(width: context.r(6)),
                      Text(l.deviceSignedOut,
                          style: TextStyle(
                              color: t.muted, fontSize: context.r(11))),
                    ],
                  ],
                ),
                SizedBox(height: context.r(2)),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.muted, fontSize: context.r(11))),
              ],
            ),
          ),
          // Revoke is offered for every device except this one — signing the
          // current device out would log the app off the account.
          if (!current)
            IconButton(
              tooltip: l.deviceRevokeAction,
              icon: Icon(Icons.logout, size: context.r(18), color: t.bad),
              onPressed: _busy ? null : () => _revoke(l, t, d),
            ),
        ],
      ),
    );
  }

  String _platformLabel(AppLocalizations l, int type) => switch (type) {
        1 => l.devicePlatformSteam,
        2 => l.devicePlatformWeb,
        3 => l.devicePlatformMobile,
        _ => l.devicePlatformUnknown,
      };

  IconData _platformIcon(int type) => switch (type) {
        1 => Icons.desktop_windows_outlined,
        2 => Icons.public,
        3 => Icons.smartphone_outlined,
        _ => Icons.devices_other_outlined,
      };

  /// Relative age of the last activity ("3d" / "5h" / "2m"), localized as a
  /// short suffix. Empty when unknown.
  String _age(AppLocalizations l, int epoch) {
    if (epoch == 0) return '';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));
    if (d.inDays > 0) return l.deviceAgeDays(d.inDays);
    if (d.inHours > 0) return l.deviceAgeHours(d.inHours);
    if (d.inMinutes > 0) return l.deviceAgeMinutes(d.inMinutes);
    return l.deviceAgeNow;
  }
}
