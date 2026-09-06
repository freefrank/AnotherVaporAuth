import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/app/settings_store.dart';
import 'src/services/image_disk_cache.dart';
import 'src/services/storage_provider.dart';
import 'src/services/portable_library.dart';
import 'src/services/window_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Age out avatar/frame images that haven't been shown in a while.
  unawaited(DiskImageCache.instance.prune());

  // Desktop only. Awaited before runApp so the window is positioned while
  // still hidden — restoring after it is on screen makes it visibly jump on
  // every launch. A failure here must never stop the app from starting.
  WindowService? window;
  if (WindowService.isSupported) {
    try {
      window = WindowService(SettingsStore(StorageProvider.forPlatform()));
      await window.restoreAndShow();
    } catch (e) {
      window = null;
      debugPrint('window restore failed, continuing: $e');
    }
  }

  final portablePath = portableDirectory(
    operatingSystem: Platform.operatingSystem,
    executable: Platform.resolvedExecutable,
    environment: Platform.environment,
  );
  final portable = portablePath == null ? null :
      PortableLibrary(DirectoryStorageProvider(portablePath));
  runApp(ProviderScope(
    overrides: [portableLibraryProvider.overrideWithValue(portable), if (window != null) windowServiceProvider.overrideWithValue(window)],
    child: const AvaApp(),
  ));
}
