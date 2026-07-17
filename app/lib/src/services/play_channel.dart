import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/channel.dart';

/// Dart side of the play-flavor native layer (billing / ads / sign-in).
/// The Kotlin counterpart lives in android/app/src/play and registers the
/// 'ava/play' MethodChannel + the 'ava/banner' platform view; on the cn
/// flavor neither exists and every call surfaces [PlayChannelUnavailable].

/// Play Console subscription product.
const kPlaySubscriptionProductId = 'ava_pro_monthly';

/// Google Cloud OAuth *web* client id used to mint id_tokens for the
/// entitlement worker. Empty until the prerequisite lands; sign-in fails
/// with 'not_configured' while empty.
const kGoogleServerClientId = '';

// Ad units: real IDs serve only in release builds; debug/profile always use
// Google's official TEST units — clicking real ads while developing counts
// as invalid traffic and endangers the AdMob account.
const _bannerAdUnitReal = 'ca-app-pub-7483086272428635/4617262774';
const _bannerAdUnitTest = 'ca-app-pub-3940256099942544/9214589741';
// NOTE: the rewarded unit still needs its SSV callback configured in AdMob
// (高级设置 → 服务器端验证) once the worker is live at api.ava.dotslash.pro.
const _rewardedAdUnitReal = 'ca-app-pub-7483086272428635/2892549348';
const _rewardedAdUnitTest = 'ca-app-pub-3940256099942544/5224354917';

const kBannerAdUnitId =
    kReleaseMode ? _bannerAdUnitReal : _bannerAdUnitTest;
const kRewardedAdUnitId =
    kReleaseMode ? _rewardedAdUnitReal : _rewardedAdUnitTest;

class PlayChannelUnavailable implements Exception {}

class PlayChannel {
  /// Injectable for tests; production uses the real 'ava/play' channel.
  final MethodChannel channel;

  const PlayChannel([this.channel = const MethodChannel('ava/play')]);

  bool get available => avaChannel == AvaChannel.play;

  Future<T> _call<T>(String method, [Object? args]) async {
    if (!available) throw PlayChannelUnavailable();
    try {
      final result = await channel.invokeMethod<T>(method, args);
      if (result == null) throw PlayChannelUnavailable();
      return result;
    } on MissingPluginException {
      // play build without the native side — should not happen, but treat
      // like cn instead of crashing.
      throw PlayChannelUnavailable();
    }
  }

  /// UMP consent gate; must run before any ad loads. True = ads may load.
  Future<bool> ensureConsent() => _call<bool>('consent.ensure');

  /// Whether UMP requires a privacy-options re-entry point (GDPR regions).
  Future<bool> privacyOptionsRequired() async {
    if (!available) return false;
    try {
      return await channel
              .invokeMethod<bool>('consent.privacyOptionsRequired') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Reopens the UMP privacy-options form (change an earlier consent choice).
  Future<void> showPrivacyOptions() => _call<bool>('consent.privacyOptions');

  /// Whether Google sign-in is configured (server client id present); the
  /// paywall flows short-circuit to 'not_configured' without any native call.
  bool get signInConfigured => kGoogleServerClientId.isNotEmpty;

  /// Google sign-in returning an id_token for the entitlement worker.
  Future<String> signInIdToken() => _call<String>(
      'signin.idToken', {'serverClientId': kGoogleServerClientId});

  /// Runs the Billing flow; resolves to the purchaseToken once PURCHASED
  /// and acknowledged. Throws PlatformException('canceled') when the user
  /// backs out.
  Future<String> subscribe() =>
      _call<String>('billing.subscribe', {'productId': kPlaySubscriptionProductId});

  /// Latest active subscription's purchaseToken, or null when none.
  Future<String?> restore() async {
    if (!available) throw PlayChannelUnavailable();
    try {
      return await channel.invokeMethod<String>('billing.restore');
    } on MissingPluginException {
      throw PlayChannelUnavailable();
    }
  }

  /// Shows a rewarded ad with SSV bound to [deviceId]; true once the
  /// reward is earned client-side (the entitlement itself arrives via the
  /// worker's SSV callback and is fetched with claimVip).
  Future<bool> showRewarded(String deviceId) => _call<bool>('rewarded.show',
      {'adUnitId': kRewardedAdUnitId, 'deviceId': deviceId});

  /// Adaptive banner height (dp) for the given width (dp).
  Future<int> bannerHeight(int widthDp) =>
      _call<int>('banner.height', {'widthDp': widthDp});
}
