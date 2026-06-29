import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';

/// Lets the user pick an existing unencrypted `*.maFile` and imports it into the
/// current store (re-encrypting under the store's passkey if it is encrypted).
Future<void> importMaFileFlow(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: l.importPickFile,
    type: FileType.any,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;

  try {
    final file = result.files.single;
    String contents;
    if (file.bytes != null) {
      contents = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      contents = await File(file.path!).readAsString();
    } else {
      throw const FormatException('no file data');
    }

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
