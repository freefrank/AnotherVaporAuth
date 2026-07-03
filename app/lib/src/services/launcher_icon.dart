import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Reconciles the Android home-screen icon with the active skin by toggling
/// launcher activity-aliases (see MainActivity.kt), which no-ops when already
/// correct. Called only at startup and when the app backgrounds — never on the
/// skin switch itself — so the swap stays invisible and never disrupts the
/// running task. No-op on other platforms and safe to call repeatedly.
class LauncherIcon {
  static const _channel = MethodChannel('ava/launcher_icon');

  static Future<void> apply(AvaSkin skin) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setIcon', {
        'skin': skin == AvaSkin.pixel ? 'pixel' : 'default',
      });
    } catch (_) {
      // Cosmetic — never let icon plumbing break a skin switch.
    }
  }
}
