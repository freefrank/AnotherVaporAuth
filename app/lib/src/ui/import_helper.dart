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
    // The filename is a last-resort SteamID source (e.g. <steamid>.maFile) for
    // exports that drop the Session block.
    await ref
        .read(appControllerProvider.notifier)
        .importMaFile(contents, sourceName: file.name);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.importSuccess)));
    }
    // One-time reminder to keep maFiles / revocation codes backed up.
    if (context.mounted) await showBackupReminderOnce(context, ref);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    }
  }
}


/// One-time reminder that authenticator data lives on this device only —
/// keep maFiles and revocation codes backed up. Shown after the first
/// successful import; the flag persists so it never repeats.
Future<void> showBackupReminderOnce(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsStoreProvider);
  if (await settings.loadBackupReminderShown()) return;
  await settings.saveBackupReminderShown();
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.backupReminderTitle),
      content: Text(l.backupReminderBody),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.backupReminderOk),
        ),
      ],
    ),
  );
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
  // Path of the plaintext maFile written below, if we get that far — kept
  // outside the try so the finally block can always find it for cleanup.
  String? path;
  try {
    final raw = (account.accountName ?? '').trim();
    final base = raw.isEmpty ? '${account.steamId}' : raw;
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final json = const JsonEncoder.withIndent('  ').convert(account.toJson());
    final dir = await getTemporaryDirectory();
    path = '${dir.path}/$safe.maFile';
    await File(path).writeAsString(json);
    // Share is asynchronous on every platform; we must await its result
    // before deleting, or the receiving app may not have finished reading
    // the file yet.
    await Share.shareXFiles([XFile(path)], subject: '$safe.maFile');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  } finally {
    // This maFile is plaintext (Steam session token, shared_secret…). Never
    // leave it behind in the temp dir — clean it up whether the share sheet
    // succeeded, was cancelled, or the export itself threw.
    if (path != null) {
      try {
        final tmp = File(path);
        if (await tmp.exists()) {
          await tmp.delete();
        }
      } catch (_) {
        // Best-effort cleanup; a failure here shouldn't mask the export's
        // own success/failure, which has already been reported above.
      }
    }
  }
}
