import 'dart:convert';

import '../core/models/steam_guard_account.dart';
import '../core/protocol/steam_auth_session.dart';
import 'debug_log.dart';
import 'session_manager.dart';
import 'steam_api_client.dart';
import 'steam_time.dart';

/// Why a headless session refresh could not complete on its own.
enum AutoLoginOutcome {
  ok, // session is valid (refresh or full re-login succeeded)
  needsPassword, // no stored password to re-login with
  needsInteractive, // an email code (or other non-TOTP guard) is required
  failed, // network / credentials error
}

/// Headless (no-UI) Steam session maintenance: refresh the short-lived access
/// token from the refresh token, and — when the refresh token itself is dead —
/// perform a full re-login using the stored password plus the account's own
/// TOTP secret (which satisfies the device-code guard automatically).
class AutoLogin {
  final SteamApiClient api;
  AutoLogin(this.api);

  /// Re-establishes [account]'s session from scratch using [password] and the
  /// account's own Steam Guard (TOTP) secret. Mutates `account.session` in place
  /// on success.
  Future<AutoLoginOutcome> reloginWithPassword(
      SteamGuardAccount account, String password) async {
    final username = account.accountName;
    if (username == null || username.isEmpty) return AutoLoginOutcome.failed;
    try {
      final s = SteamAuthSession(api);
      await s.beginWithCredentials(username, password);

      if (s.allowedConfirmations.contains(GuardType.deviceCode)) {
        final secret = account.sharedSecret;
        if (secret == null || secret.isEmpty) {
          return AutoLoginOutcome.needsInteractive;
        }
        final code = account.generateCode(SteamTime.currentSteamTime);
        await s.submitSteamGuardCode(code, GuardType.deviceCode);
      } else if (s.allowedConfirmations.contains(GuardType.emailCode)) {
        // An email code can't be produced headlessly.
        return AutoLoginOutcome.needsInteractive;
      }

      // Poll for the resulting tokens.
      for (var i = 0; i < 10; i++) {
        final r = await s.poll();
        if (r.complete) {
          final data = s.toSessionData(r);
          account.session
            ..steamId =
                data.steamId != 0 ? data.steamId : account.session.steamId
            ..accessToken = data.accessToken
            ..refreshToken = data.refreshToken;
          dlog('auto-login: ${account.accountName} re-logged in headlessly');
          return AutoLoginOutcome.ok;
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      dlog('auto-login: ${account.accountName} poll timed out');
      return AutoLoginOutcome.failed;
    } catch (e) {
      dlog('auto-login failed (${account.accountName}): $e');
      return AutoLoginOutcome.failed;
    }
  }

  /// True when the access-token JWT is absent, unparseable, or expires within
  /// [skew] — i.e. worth refreshing proactively.
  static bool accessTokenStale(String? jwt,
      {Duration skew = const Duration(minutes: 15)}) {
    if (jwt == null || jwt.isEmpty) return true;
    final parts = jwt.split('.');
    if (parts.length < 2) return true;
    try {
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (p.length % 4 != 0) {
        p += '=';
      }
      final payload =
          jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().add(skew).isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  /// Ensures [account] has a usable access token. Tries the refresh token first;
  /// if that fails, falls back to a full headless re-login using the password
  /// stored on the account (in the maFile).
  Future<AutoLoginOutcome> ensureSession(SteamGuardAccount account) async {
    if (account.session.hasTokens &&
        await SessionManager(api).refresh(account.session)) {
      return AutoLoginOutcome.ok;
    }
    final pwd = account.password;
    if (pwd == null || pwd.isEmpty) return AutoLoginOutcome.needsPassword;
    return reloginWithPassword(account, pwd);
  }
}
