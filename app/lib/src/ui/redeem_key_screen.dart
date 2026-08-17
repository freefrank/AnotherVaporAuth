// app/lib/src/ui/redeem_key_screen.dart
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/store_key_client.dart';
import '../services/debug_log.dart';
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';

/// Activates a Steam product key (CD key) on one account — the in-app
/// equivalent of the store's "Activate a Product on Steam" page.
///
/// Activation is irreversible, so the flow is deliberately two-step (type,
/// then confirm) and never retries a rejected key on its own.
class RedeemKeyScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const RedeemKeyScreen({super.key, required this.account});

  @override
  ConsumerState<RedeemKeyScreen> createState() => _RedeemKeyScreenState();
}

class _RedeemKeyScreenState extends ConsumerState<RedeemKeyScreen>
    with SessionRetryState {
  final _controller = TextEditingController();
  bool _busy = false;
  KeyRedeemResult? _result;
  String? _error;
  bool _needsLogin = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _accountLabel =>
      widget.account.accountName ??
      widget.account.personaName ??
      '${widget.account.steamId}';

  Future<void> _paste() async {
    // Clipboard access is a platform channel: it throws on a desktop session
    // with no clipboard owner, and on Android when another app holds a
    // clipboard lock. Nothing here is worth an error banner — an unhandled
    // async throw out of a button callback is.
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (e) {
      dlog('redeem: clipboard read failed: $e');
      return;
    }
    final text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    _controller.text = StoreKeyClient.normalize(text);
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  Future<void> _redeem() async {
    if (_busy) return;
    final key = StoreKeyClient.normalize(_controller.text);
    if (key.isEmpty) return;
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;

    // Irreversible write on a real Steam account — confirm before spending it.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.keyRedeemConfirm(_accountLabel)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: const Color(0xFF06060F)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.keyRedeemSubmit),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _needsLogin = false;
      _result = null;
    });
    try {
      final client = ref.read(storeKeyClientProvider);
      // retryOnAnyError: false is load-bearing. The default would re-POST the
      // key after *any* failure — including a timeout that Steam may already
      // have processed, burning a one-use key on a second activation. Only the
      // auth shapes are retried, and those are refused at the gate before the
      // key is ever consumed.
      final result = await fetchWithAutoRefresh<KeyRedeemResult>(
        widget.account,
        () => client.redeem(widget.account, key),
        retryOnAnyError: false,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
        if (result.success) _controller.clear();
      });
    } catch (e) {
      // Everything lands here: a dead session, a Dio transport failure, a
      // malformed body. The key may or may not have been consumed by a
      // request that failed late, so this path never re-sends it — the user
      // decides whether to try again.
      if (!mounted) return;
      final needsLogin = isAuthError(e);
      setState(() {
        _busy = false;
        _needsLogin = needsLogin;
        _error = needsLogin ? l.confNeedsLogin : _transportErrorText(l, e);
      });
    }
  }

  /// Readable copy for a failed request. [fetchErrorText] already unwraps
  /// [SteamApiException]; a raw `DioException.toString()` is a multi-line
  /// wall of advice aimed at developers, so network failures get the generic
  /// network message instead.
  String _transportErrorText(AppLocalizations l, Object e) =>
      e is DioException ? l.keyRedeemNetworkError : fetchErrorText(l, e);

  /// User-facing copy for a key Steam refused. [KeyRedeemError.unknown] quotes
  /// Steam's own result code rather than guessing at a reason.
  String _errorText(AppLocalizations l, KeyRedeemResult r) =>
      switch (r.error ?? KeyRedeemError.unknown) {
        KeyRedeemError.invalidKey => l.keyErrInvalid,
        KeyRedeemError.alreadyOwned => l.keyErrAlreadyOwned,
        KeyRedeemError.alreadyActivated => l.keyErrAlreadyActivated,
        KeyRedeemError.regionLocked => l.keyErrRegionLocked,
        KeyRedeemError.needsBaseProduct => l.keyErrNeedsBaseProduct,
        KeyRedeemError.needsPs3Login => l.keyErrNeedsPs3Login,
        KeyRedeemError.rateLimited => l.keyErrRateLimited,
        KeyRedeemError.unknown => l.keyErrUnknown(r.detail),
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      appBar: AppBar(title: Text(l.keyRedeemTitle)),
      body: ScanlineOverlay(
        child: ListView(
          padding: context.rSafeInsets(all: 16),
          children: [
            Text(l.keyRedeemFor(_accountLabel),
                style: TextStyle(color: t.muted, fontSize: context.r(12))),
            SizedBox(height: context.r(12)),
            _form(l, t),
            SizedBox(height: context.r(16)),
            if (_error != null)
              sessionErrorBody(
                l,
                t,
                error: _error!,
                needsLogin: _needsLogin,
                onSignIn: () => signInThen(widget.account, () {
                  if (mounted) setState(() => _error = null);
                }),
                onRetry: _redeem,
              )
            else if (_result != null)
              _resultPanel(l, t, _result!),
            SizedBox(height: context.r(16)),
            Text(l.keyRedeemNote,
                style: TextStyle(color: t.muted, fontSize: context.r(11.5))),
          ],
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l, AvaTokens t) => AvaPanel(
        padding: context.rInsets(all: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: !_busy,
              // The key is a one-use credential — autocorrect/suggestions off
              // keeps it out of the keyboard's learned dictionary, and stops
              // the IME from "fixing" a legitimate character group.
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                  fontFamily: 'monospace', letterSpacing: context.r(1.5)),
              decoration: InputDecoration(
                hintText: l.keyRedeemHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l.keyRedeemPaste,
                  icon: const Icon(Icons.content_paste),
                  onPressed: _busy ? null : _paste,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _redeem(),
            ),
            SizedBox(height: context.r(12)),
            FilledButton(
              onPressed:
                  _busy || _controller.text.trim().isEmpty ? null : _redeem,
              child: _busy
                  ? SizedBox(
                      width: context.r(18),
                      height: context.r(18),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.keyRedeemSubmit),
            ),
          ],
        ),
      );

  Widget _resultPanel(AppLocalizations l, AvaTokens t, KeyRedeemResult r) {
    if (!r.success) {
      return AvaPanel(
        padding: context.rInsets(all: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: t.bad, size: context.r(20)),
            SizedBox(width: context.r(10)),
            Expanded(child: Text(_errorText(l, r))),
          ],
        ),
      );
    }
    return AvaPanel(
      emphasized: true,
      padding: context.rInsets(all: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: t.good, size: context.r(20)),
              SizedBox(width: context.r(10)),
              Expanded(
                  child: Text(l.keyRedeemDone,
                      style: TextStyle(color: t.text))),
            ],
          ),
          SizedBox(height: context.r(10)),
          if (r.products.isEmpty)
            Text(l.keyRedeemNoProducts,
                style: TextStyle(color: t.muted, fontSize: context.r(12)))
          else ...[
            Text(l.keyRedeemGranted,
                style: TextStyle(color: t.muted, fontSize: context.r(12))),
            SizedBox(height: context.r(6)),
            for (final p in r.products)
              Padding(
                padding: context.rInsets(bottom: 2),
                child: Text('· $p',
                    style: TextStyle(
                        color: t.text, fontSize: context.r(13))),
              ),
          ],
        ],
      ),
    );
  }
}
