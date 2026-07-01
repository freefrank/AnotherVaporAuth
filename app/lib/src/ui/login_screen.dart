import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/steam_auth_session.dart';
import '../services/steam_time.dart';
import 'widgets/cooldown_button.dart';
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
  bool _canConfirm = false; // approval via the Steam app popup is available
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
    // Refresh: pull the saved password (keystore) and start the login hands-free
    // (the device code auto-submits, so no typing is needed).
    if (widget.reason == LoginReason.refresh && widget.account != null) {
      _maybeAutoLogin(widget.account!);
    }
  }

  Future<void> _maybeAutoLogin(SteamGuardAccount acc) async {
    // Password now lives on the account (maFile); fall back to the legacy
    // keystore for accounts saved by older builds.
    var pwd = acc.password;
    if (pwd == null || pwd.isEmpty) {
      pwd = await ref.read(credentialStoreProvider).password(acc.steamId);
    }
    if (!mounted || pwd == null || pwd.isEmpty || _busy) return;
    _password.text = pwd;
    _startPassword();
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
    final codeType = _session.allowedConfirmations.firstWhere(
      (g) => g == GuardType.deviceCode || g == GuardType.emailCode,
      orElse: () => GuardType.none,
    );
    // The account can also be approved by tapping "allow" in the Steam mobile
    // app (device/email confirmation) — no code required.
    final canConfirm = _session.allowedConfirmations.any((g) =>
        g == GuardType.deviceConfirmation || g == GuardType.emailConfirmation);
    // The device (TOTP) code lives in this very app — if we already hold the
    // account's secret (e.g. a session refresh), generate and submit it
    // automatically instead of asking the user to read a covered-up code.
    final acc = widget.account;
    if (codeType == GuardType.deviceCode &&
        (acc?.sharedSecret?.isNotEmpty ?? false)) {
      _autoDeviceCode(acc!, canConfirm);
      return;
    }
    setState(() {
      _busy = false;
      _needGuard = codeType;
      _canConfirm = canConfirm;
    });
    // Poll whenever approval is possible (so the app popup completes login) or
    // when no code is required at all. The code field, if shown, stays as an
    // alternative.
    if (canConfirm || codeType == GuardType.none) _beginPolling();
  }

  /// Auto-generates and submits the account's own Steam Guard (TOTP) code.
  Future<void> _autoDeviceCode(SteamGuardAccount acc, bool canConfirm) async {
    setState(() {
      _busy = true;
      _needGuard = null;
      _canConfirm = canConfirm;
      _status = AppLocalizations.of(context).loginWaiting;
    });
    try {
      final code = acc.generateCode(SteamTime.currentSteamTime);
      await _session.submitSteamGuardCode(code, GuardType.deviceCode);
      _beginPolling();
    } catch (e) {
      // Fall back to manual entry on error.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _needGuard = GuardType.deviceCode;
        _error = '$e';
      });
    }
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
    // Let the platform password manager offer to save the credentials.
    TextInput.finishAutofillContext();
    final session = _session.toSessionData(result);
    if (!mounted) return;

    if (widget.reason == LoginReason.refresh && widget.account != null) {
      final account = widget.account!;
      account.session
        ..steamId = session.steamId
        ..accessToken = session.accessToken
        ..refreshToken = session.refreshToken;
      // Remember the password in the maFile so the session can be refreshed
      // automatically next time. QR logins have no password to save.
      if (_password.text.isNotEmpty) account.password = _password.text;
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
    final hasCodeEntry = _needGuard != null && _needGuard != GuardType.none;
    final Widget content;
    if (_qrMode) {
      content = _buildQr(context, l);
    } else if (hasCodeEntry) {
      // Keep the manual code form available even while we poll for an in-app
      // approval in the background — the user can do whichever is convenient.
      content = _buildForm(context, l);
    } else if (_waiting) {
      content = _buildWaiting(context, l);
    } else {
      content = _buildForm(context, l);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.loginTitle)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: context.rInsets(all: 24),
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
                  SizedBox(height: context.r(28)),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting(BuildContext context, AppLocalizations l) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpinnerRing(
          size: context.r(96),
          child: Icon(Icons.phone_android, color: t.accent, size: context.r(34)),
        ),
        SizedBox(height: context.r(22)),
        Text(l.loginWaiting,
            style: TextStyle(color: t.text, fontSize: context.r(15)),
            textAlign: TextAlign.center),
        SizedBox(height: context.r(8)),
        Text(l.loginWaitingDesc,
            style: TextStyle(color: t.muted, fontSize: context.r(13), height: 1.5),
            textAlign: TextAlign.center),
        SizedBox(height: context.r(18)),
        if (_error != null)
          Text(_error!, style: TextStyle(color: t.bad)),
      ],
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l) {
    if (_needGuard != null && _needGuard != GuardType.none) {
      final isEmail = _needGuard == GuardType.emailCode;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isEmail ? l.loginNeedEmailCode : l.loginNeedGuardCode),
          if (_canConfirm) ...[
            SizedBox(height: context.r(6)),
            Text(l.loginOrApprove,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: context.r(12.5),
                    color: Theme.of(context)
                        .extension<SdaTokens>()
                        ?.muted)),
          ],
          SizedBox(height: context.r(12)),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) => _submitCode(),
          ),
          SizedBox(height: context.r(12)),
          CooldownButton(
            onPressed: _busy ? null : _submitCode,
            child: Text(l.loginSubmitCode),
          ),
          if (_status != null) ...[
            SizedBox(height: context.r(12)),
            Text(_status!),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _username,
                enabled: widget.reason == LoginReason.add,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.loginUsername,
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: context.r(12)),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l.loginPassword,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _startPassword(),
              ),
            ],
          ),
        ),
        SizedBox(height: context.r(16)),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _startPassword,
            child: _busy
                ? SizedBox(
                    height: context.r(18),
                    width: context.r(18),
                    child: CircularProgressIndicator(strokeWidth: context.r(2)))
                : Text(l.loginButton),
          ),
        ),
        SizedBox(height: context.r(8)),
        TextButton.icon(
          onPressed: _busy ? null : _startQr,
          icon: const Icon(Icons.qr_code),
          label: Text(l.loginViaQr),
        ),
        if (_error != null) ...[
          SizedBox(height: context.r(12)),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _buildQr(BuildContext context, AppLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.loginScanWithApp, textAlign: TextAlign.center),
        SizedBox(height: context.r(16)),
        if (_qrUrl != null && _qrUrl!.isNotEmpty)
          Container(
            color: Colors.white,
            padding: context.rInsets(all: 12),
            child: QrImageView(data: _qrUrl!, size: context.r(220)),
          )
        else
          const CircularProgressIndicator(),
        SizedBox(height: context.r(16)),
        if (_status != null) Text(_status!),
        TextButton(
          onPressed: () => setState(() {
            _qrMode = false;
            _pollTimer?.cancel();
          }),
          child: Text(l.loginViaCredentials),
        ),
        if (_error != null) ...[
          SizedBox(height: context.r(12)),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }
}
