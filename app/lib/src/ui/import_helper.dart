import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../core/models/steam_guard_account.dart';

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

/// Exports an account as an **unencrypted** `*.maFile` (plain JSON), named after
/// the account's username, via the system share sheet (save to Files, Drive…).
Future<void> exportMaFileFlow(
    BuildContext context, SteamGuardAccount account) async {
  final l = AppLocalizations.of(context);
  // The export is a plaintext maFile — warn before it leaves the app, and call
  // out a saved password specifically since it travels with the file.
  final hasPassword = (account.password ?? '').isNotEmpty;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.exportWarnTitle),
      content: Text(
        hasPassword
            ? '${l.exportWarnBody}\n\n${l.exportWarnPassword}'
            : l.exportWarnBody,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonExport)),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final raw = (account.accountName ?? '').trim();
    final base = raw.isEmpty ? '${account.steamId}' : raw;
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final json = const JsonEncoder.withIndent('  ').convert(account.toJson());
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$safe.maFile';
    await File(path).writeAsString(json);
    await Share.shareXFiles([XFile(path)], subject: '$safe.maFile');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  }
}
