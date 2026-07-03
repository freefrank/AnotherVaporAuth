import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Keeps the Android home-screen icon in sync with the active skin by
/// toggling launcher activity-aliases (see MainActivity.kt). No-op on
/// other platforms and safe to call repeatedly.
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
