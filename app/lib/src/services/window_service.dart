import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../app/settings_store.dart';
import '../core/window_bounds.dart';
import 'debug_log.dart';

/// Remembers where the desktop window was and puts it back.
///
/// Nothing here runs on Android or iOS — [isSupported] gates every entry
/// point, and window_manager declares no mobile platform, so the plugin is
/// not even registered there.
class WindowService with WindowListener {
  WindowService(this.settings);

  final SettingsStore settings;

  static bool get isSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Writes are debounced: dragging a window emits a move event per frame,
  /// and each one would otherwise rewrite app_settings.json.
  static const _writeDelay = Duration(milliseconds: 400);
  Timer? _pending;

  /// The last geometry seen while *not* maximized. Maximizing reports the
  /// full-screen bounds, which must not become what the window restores to.
  Rect? _restored;
  bool _maximized = false;

  /// Restores the saved geometry, then shows the window.
  ///
  /// The window starts hidden (see the runner's `windowManager.waitUntil…`
  /// contract): showing it first and moving it afterwards makes the window
  /// visibly jump across the screen on every launch.
  Future<void> restoreAndShow() async {
    if (!isSupported) return;
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(minWindowSize);

    WindowGeometry? saved;
    try {
      saved = WindowGeometry.fromJson(await settings.loadWindowGeometry());
    } catch (e) {
      // A settings read can fail transiently. Losing the window position is
      // not worth failing a launch over.
      dlog('window: could not read saved geometry ($e)');
    }

    if (saved != null) {
      final fitted = fitToDisplays(saved.bounds, await _displays());
      if (fitted != null) {
        await windowManager.setBounds(fitted);
        _restored = fitted;
      } else {
        // No display information: keep the size, let the platform place it.
        await windowManager.setSize(saved.bounds.size);
        await windowManager.center();
      }
      _maximized = saved.maximized;
      if (saved.maximized) await windowManager.maximize();
    }

    windowManager.addListener(this);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<List<Rect>> _displays() async {
    try {
      final all = await screenRetriever.getAllDisplays();
      return [
        for (final d in all)
          Rect.fromLTWH(
            d.visiblePosition?.dx ?? 0,
            d.visiblePosition?.dy ?? 0,
            (d.visibleSize ?? d.size).width,
            (d.visibleSize ?? d.size).height,
          ),
      ];
    } catch (e) {
      // Treated as "no information", which centres rather than guesses.
      dlog('window: display enumeration failed ($e)');
      return const [];
    }
  }

  // ---- WindowListener ----

  @override
  void onWindowMoved() => _schedule();

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMaximize() {
    _maximized = true;
    _schedule();
  }

  @override
  void onWindowUnmaximize() {
    _maximized = false;
    _schedule();
  }

  /// Persist on close too: a window moved and then quit within the debounce
  /// window would otherwise be forgotten.
  @override
  void onWindowClose() => unawaited(_persist());

  void _schedule() {
    _pending?.cancel();
    _pending = Timer(_writeDelay, () => unawaited(_persist()));
  }

  Future<void> _persist() async {
    _pending?.cancel();
    try {
      // Only sample bounds while restored. While maximized the reported
      // bounds are the screen's, and saving those would make un-maximizing
      // after a restart do nothing visible.
      if (!await windowManager.isMaximized()) {
        _restored = await windowManager.getBounds();
      }
      final bounds = _restored;
      if (bounds == null) return;
      await settings.saveWindowGeometry(
        WindowGeometry(bounds: bounds, maximized: _maximized).toJson(),
      );
    } catch (e) {
      dlog('window: could not save geometry ($e)');
    }
  }

  void dispose() {
    _pending?.cancel();
    if (isSupported) windowManager.removeListener(this);
  }
}
