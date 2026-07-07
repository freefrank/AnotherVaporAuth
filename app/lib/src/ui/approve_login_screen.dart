import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/qr_approval_client.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';

/// Streamlined entry for the home screen's top-right scan button: on touch
/// devices, jump straight into the camera for [account] and confirm from a
/// dialog showing where the sign-in comes from; desktop (no camera) falls
/// back to the full screen with the paste field, preselected to [account].
Future<void> quickApproveLogin(
    BuildContext context, WidgetRef ref, SteamGuardAccount account) async {
  final l = AppLocalizations.of(context);
  if (!(Platform.isAndroid || Platform.isIOS)) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ApproveLoginScreen(initialAccount: account)));
    return;
  }
  if (!account.session.hasTokens) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.sessionExpired)));
    return;
  }
  final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()));
  if (code == null || !context.mounted) return;
  final challenge = QrChallenge.tryParse(code);
  if (challenge == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.approveBadCode)));
    return;
  }
  final client = QrApprovalClient(ref.read(apiClientProvider));
  // Best-effort context (IP / location / device) for the confirm dialog —
  // the approval itself works without it.
  AuthSessionInfo? info;
  try {
    info = await client.sessionInfo(account, challenge.clientId);
  } catch (_) {}
  if (!context.mounted) return;
  final approve = await _confirmApproveDialog(context, account, info);
  if (approve == null || !context.mounted) return;
  try {
    final ok = await client.respond(account, challenge, approve: approve);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (approve ? l.approveSuccess : l.approveRejected)
            : l.commonError)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${l.commonError}: $e')));
  }
}

Future<bool?> _confirmApproveDialog(BuildContext context,
    SteamGuardAccount account, AuthSessionInfo? info) {
  final l = AppLocalizations.of(context);
  final t = Theme.of(context).extension<AvaTokens>()!;
  Widget detail(String text) => Padding(
        padding: EdgeInsets.only(top: context.r(3)),
        child: Text(text,
            style: TextStyle(color: t.muted, fontSize: context.r(13))),
      );
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.approveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account.accountName ?? '${account.steamId}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: context.r(15))),
          SizedBox(height: context.r(6)),
          if (info != null) ...[
            if (info.location.isNotEmpty)
              detail('${l.approveLocation}: ${info.location}'),
            if (info.ip.isNotEmpty) detail('IP: ${info.ip}'),
            if (info.deviceName.isNotEmpty)
              detail('${l.approveDevice}: ${info.deviceName}'),
          ],
          SizedBox(height: context.r(12)),
          Text(l.approveWarnStranger,
              style: TextStyle(color: t.warn, fontSize: context.r(12.5))),
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.approveReject)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.approveButton)),
      ],
    ),
  );
}

class ApproveLoginScreen extends ConsumerStatefulWidget {
  /// Preselects this account in the dropdown (if it has a live session).
  final SteamGuardAccount? initialAccount;
  const ApproveLoginScreen({super.key, this.initialAccount});

  @override
  ConsumerState<ApproveLoginScreen> createState() =>
      _ApproveLoginScreenState();
}

class _ApproveLoginScreenState extends ConsumerState<ApproveLoginScreen> {
  final _link = TextEditingController();
  SteamGuardAccount? _account;
  bool _busy = false;
  String? _message;

  bool get _canScan => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    if (code != null) setState(() => _link.text = code);
  }

  Future<void> _respond(bool approve) async {
    final l = AppLocalizations.of(context);
    final account = _account;
    if (account == null) return;
    final challenge = QrChallenge.tryParse(_link.text);
    if (challenge == null) {
      setState(() => _message = l.commonError);
      return;
    }
    setState(() => _busy = true);
    final client = QrApprovalClient(ref.read(apiClientProvider));
    var finalApprove = approve;
    if (approve) {
      // Anti-phishing gate: never approve blind. Pull best-effort context
      // (IP / location / device) and make the user confirm it's really them
      // via the same dialog the quick-scan path (quickApproveLogin above)
      // shows, before actually sending approve:true.
      AuthSessionInfo? info;
      try {
        info = await client.sessionInfo(account, challenge.clientId);
      } catch (_) {}
      if (!mounted) return;
      final confirmed = await _confirmApproveDialog(context, account, info);
      if (!mounted) return;
      if (confirmed == null) {
        setState(() => _busy = false);
        return;
      }
      finalApprove = confirmed;
    }
    try {
      final ok =
          await client.respond(account, challenge, approve: finalApprove);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = ok
            ? (finalApprove ? l.approveSuccess : l.approveRejected)
            : l.commonError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '${l.commonError}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accounts = (ref.watch(appControllerProvider).value?.accounts ??
            const <SteamGuardAccount>[])
        .where((a) => a.session.hasTokens)
        .toList();
    _account ??= accounts.contains(widget.initialAccount)
        ? widget.initialAccount
        : (accounts.isNotEmpty ? accounts.first : null);

    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      appBar: AppBar(title: Text(l.approveTitle)),
      body: ScanlineOverlay(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: context.rInsets(all: 24),
            child: AvaPanel(
              padding: context.rInsets(all: 20),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.qr_code_2, size: context.r(40), color: t.accent),
                SizedBox(height: context.r(14)),
                if (accounts.isEmpty)
                  Text(l.sessionExpired)
                else
                  DropdownButtonFormField<SteamGuardAccount>(
                    initialValue: _account,
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a.accountName ?? '${a.steamId}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _account = v),
                  ),
                SizedBox(height: context.r(16)),
                Text(l.approveScanPrompt),
                SizedBox(height: context.r(8)),
                if (_canScan)
                  OutlinedButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l.approveTitle),
                  ),
                SizedBox(height: context.r(8)),
                TextField(
                  controller: _link,
                  decoration: InputDecoration(
                    labelText: l.approvePastePrompt,
                    border: const OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: context.r(16)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busy || accounts.isEmpty ? null : () => _respond(false),
                        child: Text(l.approveReject),
                      ),
                    ),
                    SizedBox(width: context.r(8)),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _busy || accounts.isEmpty ? null : () => _respond(true),
                        child: Text(l.approveButton),
                      ),
                    ),
                  ],
                ),
                if (_message != null) ...[
                  SizedBox(height: context.r(16)),
                  Text(_message!, textAlign: TextAlign.center),
                ],
              ],
            ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  // MobileScanner keeps re-detecting the same code every frame while the pop
  // animation plays; without this latch each extra detection pops another
  // route *below* the scanner, leaving a blank Navigator.
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // "Sign in with QR" — the user came here to scan; "approve" only makes
      // sense on the confirm step that follows.
      appBar: AppBar(title: Text(AppLocalizations.of(context).loginViaQr)),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final code = capture.barcodes
              .map((b) => b.rawValue)
              .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
          if (code == null) return;
          _done = true;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
