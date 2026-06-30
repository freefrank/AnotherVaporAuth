import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';

/// Lets the user pick an existing unencrypted `*.maFile` and imports it into the
/// current store (re-encrypting under the store's passkey if it is encrypted).
///
/// Uses file_selector (flutter.dev official). `.maFile` is a custom extension,
/// so we accept any file rather than relying on extension/MIME filtering.
Future<void> importMaFileFlow(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final XFile? file = await openFile();
  if (file == null) return;

  try {
    final contents = await file.readAsString();
    // Validate it parses as JSON before importing.
    jsonDecode(contents);
    await ref.read(appControllerProvider.notifier).importMaFile(contents);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.importSuccess)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    }
  }
}
