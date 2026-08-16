import 'dart:async';

import 'package:flutter/services.dart';

import 'debug_log.dart';
import 'entitlement_store.dart';
import 'play_channel.dart';

/// Outcome of a paywall action, mapped to UI copy by error [code]:
/// 'canceled' | 'not_configured' | 'no_credential' | 'billing_unavailable' |
/// 'unavailable' | 'no_subscription' | 'consent' | 'not_earned' | 'no_vip' |
/// 'order_bound' | 'order_invalid' | 'device_revoked' | 'code_invalid' |
/// 'code_activation_limit' | 'code_redeemed' (legacy — pre per-class-slot
/// workers only) | 'bad_token' | 'network' | worker codes…
class ProResult {
  final bool ok;
  final String? code;

  /// Occupied device-class slots carried by the worker's refusal body
  /// ('code_activation_limit' attaches them) — lets the UI say which class
  /// holds the slot instead of a dead-end "try later".
  final List<EntitlementActivation>? activations;

  /// Masked bound-account hint riding 'purchase_token_bound'.
  final String? boundHint;

  const ProResult.success()
      : ok = true,
        code = null,
        activations = null,
        boundHint = null;
  const ProResult.fail(this.code, {this.activations, this.boundHint})
      : ok = false;
}

/// Orchestrates purchase / redeem / rewarded flows: native play channel →
/// entitlement worker → token adoption. Pure DI, no riverpod imports.
class ProActions {
  final EntitlementApi api;
  final PlayChannel play;
  final Future<String> Function() deviceId;

  /// EntitlementTokenController.adopt — false when the token fails to verify.
  final Future<bool> Function(String raw) adopt;
  final String deviceClass;

  /// Wait between claimVip polls (SSV callback may lag the client reward).
  final Duration vipClaimDelay;
  final int vipClaimAttempts;

  ProActions({
    required this.api,
    required this.play,
    required this.deviceId,
    required this.adopt,
    required this.deviceClass,
    this.vipClaimDelay = const Duration(seconds: 2),
    this.vipClaimAttempts = 6,
  });

  Future<ProResult> _guard(Future<ProResult> Function() body) async {
    try {
      return await body();
    } on PlayChannelUnavailable {
      return const ProResult.fail('unavailable');
    } on PlatformException catch (e) {
      return ProResult.fail(e.code);
    } on EntitlementApiException catch (e) {
      return ProResult.fail(e.code,
          activations: e.activations, boundHint: e.boundHint);
    } catch (e) {
      dlog('pro: action failed: $e');
      return const ProResult.fail('network');
    }
  }

  Future<ProResult> _adoptFrom(String raw) async =>
      await adopt(raw) ? const ProResult.success() : const ProResult.fail('bad_token');

  /// Play: sign in first (identifies the entitlement owner), THEN run the
  /// billing flow. Sign-in failing after an acknowledged purchase would
  /// strand the user charged-but-unentitled.
  Future<ProResult> subscribeViaPlay() => _guard(() async {
        if (!play.signInConfigured) return const ProResult.fail('not_configured');
        final idToken = await play.signInIdToken();
        final purchaseToken = await play.subscribe();
        return _adoptFrom(await api.verifyPlay(
          idToken: idToken,
          purchaseToken: purchaseToken,
          deviceId: await deviceId(),
          deviceClass: deviceClass,
        ));
      });

  /// Play: restore an existing subscription on this device. Restore runs
  /// before sign-in (it charges nothing and avoids an account-picker just to
  /// learn "no subscription"); the configured-guard keeps the native
  /// acknowledge from running when sign-in is guaranteed to fail.
  Future<ProResult> restoreViaPlay() => _guard(() async {
        if (!play.signInConfigured) return const ProResult.fail('not_configured');
        final purchaseToken = await play.restore();
        if (purchaseToken == null) return const ProResult.fail('no_subscription');
        final idToken = await play.signInIdToken();
        return _adoptFrom(await api.verifyPlay(
          idToken: idToken,
          purchaseToken: purchaseToken,
          deviceId: await deviceId(),
          deviceClass: deviceClass,
        ));
      });

  /// cn: unlock with an Afdian order number.
  Future<ProResult> redeemAfdian(String orderNo) => _guard(() async {
        return _adoptFrom(await api.redeemAfdian(
          orderNo: orderNo.trim(),
          deviceId: await deviceId(),
          deviceClass: deviceClass,
        ));
      });

  /// Beta lifetime code (both channels).
  Future<ProResult> redeemBeta(String code) => _guard(() async {
        return _adoptFrom(await api.redeemBeta(
          code: code.trim(),
          deviceId: await deviceId(),
          deviceClass: deviceClass,
        ));
      });

  /// Play: rewarded ad → 3-day VIP. The reward lands server-side via SSV,
  /// so after the ad we poll claimVip until the entitlement shows up.
  Future<ProResult> watchRewarded() => _guard(() async {
        if (!await play.ensureConsent()) return const ProResult.fail('consent');
        final dev = await deviceId();
        if (!await play.showRewarded(dev)) {
          return const ProResult.fail('not_earned');
        }
        for (var i = 0; i < vipClaimAttempts; i++) {
          try {
            return _adoptFrom(
                await api.claimVip(deviceId: dev, deviceClass: deviceClass));
          } on EntitlementApiException catch (e) {
            if (e.status != 404) rethrow;
            await Future<void>.delayed(vipClaimDelay);
          }
        }
        return const ProResult.fail('no_vip');
      });
}
