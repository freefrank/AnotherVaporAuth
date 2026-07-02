import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/services/image_disk_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Age out avatar/frame images that haven't been shown in a while.
  unawaited(DiskImageCache.instance.prune());
  runApp(const ProviderScope(child: AvaApp()));
}
