import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/protocol/confirmations_client.dart'
    show ConfirmationAuthException;
import '../../services/session_manager.dart';
import '../../services/steam_api_client.dart'
    show SteamApiException, isSessionDeadError;
import '../login_screen.dart';

/// 待办三页签、家庭组页与市场页共用的"会话续期 + 重登"骨架。原先每屏各养
/// 一份拷贝——每个修复都得抄五遍(persistSession/mounted 守卫那批就是这么
/// 付的)。提供:
/// - [fetchWithAutoRefresh]:拉取失败先用 refresh token 换新 access token、
///   持久化,再重试一次;
/// - [isAuthError]:哪些异常意味着"会话已死,只有交互式登录能救";
/// - [signInThen]:进登录页,回来后重拉;
/// - [scrollableCentered] + [sessionErrorBody]:错误态的标准骨架。
mixin SessionRetryState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// True for the error shapes that mean "the session is dead and only an
  /// interactive sign-in can fix it". [isSessionDeadError] covers the shared
  /// vocabulary (no access token at all, a community-transport auth
  /// rejection, Steam answering the already-refreshed retry with a bare
  /// 401/403); [ConfirmationAuthException] is the mobileconf transport's own
  /// needauth signal, folded in here so every tab classifies alike.
  bool isAuthError(Object e) =>
      isSessionDeadError(e) || e is ConfirmationAuthException;

  /// Fetches via [fetch]; on failure it refreshes the access token from the
  /// refresh token and retries once. Rethrows when the refresh doesn't help.
  /// [retryOnAnyError] false limits the refresh+retry to [isAuthError]
  /// shapes — the confirmations transport signals a stale session with a
  /// typed exception, so other failures there aren't worth a token exchange.
  Future<R> fetchWithAutoRefresh<R>(
    SteamGuardAccount account,
    Future<R> Function() fetch, {
    bool retryOnAnyError = true,
  }) async {
    // Captured up front: `ref` on a disposed State throws, and the renewed
    // (possibly rotated) refresh token must be persisted even if this screen
    // is gone by the time the exchange returns.
    final controller = ref.read(appControllerProvider.notifier);
    final api = ref.read(apiClientProvider);
    try {
      return await fetch();
    } catch (e) {
      if (!retryOnAnyError && !isAuthError(e)) rethrow;
      final refreshed = await SessionManager(api).refresh(account.session);
      if (!refreshed) rethrow;
      await controller.persistSession(account);
      return await fetch();
    }
  }

  /// Opens sign-in for [account], then runs [onReturn] (usually the screen's
  /// refresh) when the user comes back with this State still mounted.
  Future<void> signInThen(
      SteamGuardAccount account, VoidCallback onReturn) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          LoginScreen(reason: LoginReason.refresh, account: account),
    ));
    if (mounted) onReturn();
  }

  /// User-facing text for a failed fetch that is *not* a dead session:
  /// SteamApiException 的完整 toString 对用户像未捕获的崩溃 —— 只显示其
  /// message(如 "HTTP 405"),其余异常保持原样。
  String fetchErrorText(Object e) =>
      e is SteamApiException ? e.message : '$e';

  /// Wraps [child] in a scrollable that fills the viewport and centers it —
  /// RefreshIndicator needs a scrollable to trigger, and the content must
  /// stay vertically centered (and able to grow) on any screen height.
  Widget scrollableCentered(Widget child) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ],
        ),
      );

  /// The standard fetch-error body: cloud-off icon, the message, and either
  /// a sign-in button (dead session) or a retry.
  Widget sessionErrorBody(
    AppLocalizations l,
    AvaTokens t, {
    required String error,
    required bool needsLogin,
    required VoidCallback onSignIn,
    required VoidCallback onRetry,
  }) =>
      Padding(
        padding: context.rInsets(all: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: t.muted, size: context.r(40)),
            SizedBox(height: context.r(12)),
            Text(
              needsLogin ? error : '${l.commonError}: $error',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.r(16)),
            needsLogin
                ? FilledButton(onPressed: onSignIn, child: Text(l.loginButton))
                : OutlinedButton(
                    onPressed: onRetry, child: Text(l.commonRetry)),
          ],
        ),
      );
}
