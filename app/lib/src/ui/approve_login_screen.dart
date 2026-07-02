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

class ApproveLoginScreen extends ConsumerStatefulWidget {
  const ApproveLoginScreen({super.key});

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
    try {
      final client = QrApprovalClient(ref.read(apiClientProvider));
      final ok = await client.respond(account, challenge, approve: approve);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = ok
            ? (approve ? l.approveSuccess : l.approveRejected)
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
    _account ??= accounts.isNotEmpty ? accounts.first : null;

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

class _ScannerPage extends StatelessWidget {
  const _ScannerPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).approveTitle)),
      body: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes
              .map((b) => b.rawValue)
              .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
          if (code != null) Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
