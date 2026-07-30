import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'debug_log.dart';

/// Android's `FLAG_SECURE`: excludes the window from screenshots, screen
/// recording, and the recent-apps thumbnail.
///
/// Opt-in rather than always-on. The flag is all-or-nothing per window, so
/// turning it on also blacks out legitimate screen sharing and the
/// screenshots users attach to bug reports — a cost worth paying only when
/// the user says so. Off by default; see [kScreenSecurityDefault].
///
/// Android only. Windows and macOS have no equivalent a Flutter app can set
/// from the framework side, and X11/Wayland have none at all, so the setting
/// is hidden off-Android instead of pretending to work.
class ScreenSecurity {
  static const _channel = MethodChannel('ava/screen_security');

  /// Test-only override for [supported]. Without it every test would run on
  /// a host where `supported` is false, so `apply` would return before
  /// touching the channel and the assertions would hold for the wrong reason.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Whether this platform can honour the flag at all — gates both the
  /// setting's visibility and the channel call.
  static bool get supported =>
      debugSupportedOverride ?? (!kIsWeb && Platform.isAndroid);

  /// Best-effort: a failure here must never block a settings toggle or app
  /// startup. Logged rather than thrown so a missing handler (a stale engine,
  /// a platform without the channel) degrades to "screenshots stay allowed",
  /// which is the default anyway.
  static Future<void> apply(bool enabled) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } on PlatformException catch (e) {
      dlog('screen_security: setSecure($enabled) failed — ${e.code}');
    } on MissingPluginException {
      dlog('screen_security: channel unavailable');
    }
  }
}

/// Screenshots are allowed unless the user opts out.
const bool kScreenSecurityDefault = false;
