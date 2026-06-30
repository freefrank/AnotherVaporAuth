import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/steam_auth_session.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/stepper3.dart';
import 'add_authenticator_screen.dart';

enum LoginReason { add, refresh }

class LoginScreen extends ConsumerStatefulWidget {
  final LoginReason reason;
  final SteamGuardAccount? account;
  const LoginScreen({super.key, required this.reason, this.account});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final SteamAuthSession _session;
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _qrMode = false;
  String? _qrUrl;
  bool _busy = false;
  bool _waiting = false; // polling for mobile/email confirmation
  String? _status;
  String? _error;
  GuardType? _needGuard;
  Timer? _pollTimer;

  /// Stepper position: 0 credentials, 1 confirm, 2 done.
  int get _step => (_waiting || _needGuard != null || _qrMode) ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _session = SteamAuthSession(ref.read(apiClientProvider));
    if (widget.account?.accountName != null) {
      _username.text = widget.account!.accountName!;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _startPassword() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await _session.beginWithCredentials(_username.text, _password.text);
      _afterBegin();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _startQr() async {
    setState(() {
      _qrMode = true;
      _busy = true;
      _error = null;
    });
    try {
      final url = await _session.beginWithQr();
      setState(() {
        _qrUrl = url;
        _busy = false;
      });
      _beginPolling();
    } catch (e) {
      _fail(e);
    }
  }

  void _afterBegin() {
    final needsCode = _session.allowedConfirmations.any((g) =>
        g == GuardType.deviceCode || g == GuardType.emailCode);
    setState(() {
      _busy = false;
      _needGuard = _session.allowedConfirmations.firstWhere(
        (g) => g == GuardType.deviceCode || g == GuardType.emailCode,
        orElse: () => GuardType.none,
      );
    });
    if (!needsCode) _beginPolling();
  }

  Future<void> _submitCode() async {
    final guard = _needGuard;
    if (guard == null || guard == GuardType.none) return;
    setState(() => _busy = true);
    try {
      await _session.submitSteamGuardCode(_code.text, guard);
      setState(() {
        _busy = false;
        _needGuard = null;
      });
      _beginPolling();
    } catch (e) {
      _fail(e);
    }
  }

  void _beginPolling() {
    final l = AppLocalizations.of(context);
    setState(() {
      _status = l.loginWaiting;
      _waiting = !_qrMode;
    });
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final result = await _session.poll();
        if (result.newChallengeUrl != null &&
            result.newChallengeUrl!.isNotEmpty &&
            _qrMode) {
          setState(() => _qrUrl = result.newChallengeUrl);
        }
        if (result.complete) {
          _pollTimer?.cancel();
          await _onLoggedIn(result);
        }
      } catch (e) {
        _pollTimer?.cancel();
        _fail(e);
      }
    });
  }

  Future<void> _onLoggedIn(PollResult result) async {
    final session = _session.toSessionData(result);
    if (!mounted) return;

    if (widget.reason == LoginReason.refresh && widget.account != null) {
      final account = widget.account!;
      account.session
        ..steamId = session.steamId
        ..accessToken = session.accessToken
        ..refreshToken = session.refreshToken;
      account.fullyEnrolled = true;
      await ref.read(appControllerProvider.notifier).persistAccount(account);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // reason == add: proceed to authenticator linking.
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AddAuthenticatorScreen(session: session),
      ));
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = false;
      _error = l.loginFailed('$e');
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final Widget content = _waiting
        ? _buildWaiting(l)
        : (_qrMode ? _buildQr(l) : _buildForm(l));
    return Scaffold(
      appBar: AppBar(title: Text(l.loginTitle)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stepper3(
                    current: _step,
                    labels: [
                      l.loginStepCredentials,
                      l.loginStepConfirm,
                      l.loginStepDone,
                    ],
                  ),
                  const SizedBox(height: 28),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting(AppLocalizations l) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpinnerRing(
          size: 96,
          child: Icon(Icons.phone_android, color: t.accent, size: 34),
        ),
        const SizedBox(height: 22),
        Text(l.loginWaiting,
            style: TextStyle(color: t.text, fontSize: 15),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(l.loginWaitingDesc,
            style: TextStyle(color: t.muted, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 18),
        if (_error != null)
          Text(_error!, style: TextStyle(color: t.bad)),
      ],
    );
  }

  Widget _buildForm(AppLocalizations l) {
    if (_needGuard != null && _needGuard != GuardType.none) {
      final isEmail = _needGuard == GuardType.emailCode;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isEmail ? l.loginNeedEmailCode : l.loginNeedGuardCode),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) => _submitCode(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submitCode,
            child: Text(l.loginSubmitCode),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _username,
          enabled: widget.reason == LoginReason.add,
          decoration: InputDecoration(
            labelText: l.loginUsername,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l.loginPassword,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _startPassword(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _startPassword,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.loginButton),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _busy ? null : _startQr,
          icon: const Icon(Icons.qr_code),
          label: Text(l.loginViaQr),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _buildQr(AppLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.loginScanWithApp, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (_qrUrl != null && _qrUrl!.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(data: _qrUrl!, size: 220),
          )
        else
          const CircularProgressIndicator(),
        const SizedBox(height: 16),
        if (_status != null) Text(_status!),
        TextButton(
          onPressed: () => setState(() {
            _qrMode = false;
            _pollTimer?.cancel();
          }),
          child: Text(l.loginViaCredentials),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }
}
