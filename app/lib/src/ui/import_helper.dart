import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/crypto/secure_random.dart';
import '../core/models/steam_guard_account.dart';
import '../services/session_manager.dart';
import 'login_screen.dart';

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
    // Re-importing an already-stored SteamID is a wholesale overwrite of the
    // stored account — never do that silently; ask first. When the manifest
    // entry exists but the stored account can't be decoded, the "kept" copy
    // would be a lie — say the import replaces everything instead.
    final notifier = ref.read(appControllerProvider.notifier);
    final dup = notifier.findImportCollision(contents, sourceName: file.name);
    if (dup != null) {
      if (!context.mounted) return;
      final name = (dup.account.accountName ?? dup.account.personaName ?? '')
          .trim();
      final label = name.isEmpty ? '${dup.account.steamId}' : name;
      final t = Theme.of(context).extension<AvaTokens>()!;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.importDuplicateTitle),
          content: Text(
            dup.storedReadable
                ? l.importDuplicateBody(label)
                : l.importDuplicateBodyUnreadable(label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            // Overwrite replaces stored secrets/session — destructive styling.
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.bad,
                foregroundColor: const Color(0xFF06060F),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.importDuplicateOverwrite),
            ),
          ],
        ),
      );
      if (overwrite != true) return; // user kept the existing account
      if (!context.mounted) return;
    }
    // The filename is a last-resort SteamID source (e.g. <steamid>.maFile) for
    // exports that drop the Session block.
    final account = await notifier.importMaFile(
      contents,
      sourceName: file.name,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.importSuccess)));
    }
    // A maFile's session has usually already died on the source device by the
    // time it's imported here — reactivate it now instead of leaving the user
    // to stumble on the home screen's "refresh session" entry on their own.
    if (context.mounted) {
      await _activateImportedSession(context, ref, account);
    }
    // One-time reminder to keep maFiles / revocation codes backed up. Runs
    // after the session dialog above (never both at once) so at most one
    // dialog is ever on screen.
    if (context.mounted) await showBackupReminderOnce(context, ref);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    }
  }
}

/// Whether a freshly-imported account's session was reactivated silently —
/// it had tokens *and* the refresh call succeeded — versus needing the user
/// to sign in by hand. Split out from [_activateImportedSession] as a pure
/// decision so the branching is unit-testable without mocking the network
/// refresh call.
@visibleForTesting
bool sessionActivatedSilently({
  required bool hasTokens,
  required bool refreshSucceeded,
}) => hasTokens && refreshSucceeded;

/// Tries to silently refresh [account]'s session right after import; when
/// that isn't possible (no tokens in the maFile, or the refresh call failed)
/// offers to sign in now instead, prefilling [LoginScreen] with the account.
Future<void> _activateImportedSession(
  BuildContext context,
  WidgetRef ref,
  SteamGuardAccount account,
) async {
  final hasTokens = account.session.hasTokens;
  // Short-circuits: refresh is only attempted (and awaited) when there is a
  // token to refresh in the first place.
  final refreshSucceeded =
      hasTokens &&
      await SessionManager(
        ref.read(apiClientProvider),
      ).refresh(account.session);
  if (sessionActivatedSilently(
    hasTokens: hasTokens,
    refreshSucceeded: refreshSucceeded,
  )) {
    // Best-effort: the account is already on disk from the import itself, so
    // a write failure here just means the refreshed token isn't persisted
    // yet — not worth failing the (already successful) import over.
    try {
      await ref.read(appControllerProvider.notifier).persistAccount(account);
    } catch (_) {}
    return;
  }
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final signInNow = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.importSessionDeadTitle),
      content: Text(l.importSessionDeadBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.importSessionLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.importSessionLoginNow),
        ),
      ],
    ),
  );
  if (signInNow != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          LoginScreen(reason: LoginReason.refresh, account: account),
    ),
  );
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
  BuildContext context,
  SteamGuardAccount account,
) async {
  final l = AppLocalizations.of(context);
  // The export is a plaintext maFile — warn before it leaves the app. A saved
  // Steam password is stripped from the export unless the user opts in here.
  final hasPassword = (account.password ?? '').isNotEmpty;
  var includePassword = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.exportWarnTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.exportWarnBody),
            if (hasPassword)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: includePassword,
                onChanged: (v) => setState(() => includePassword = v ?? false),
                title: Text(l.exportIncludePassword),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonExport),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  // Path of the plaintext maFile written below, and the private directory
  // holding it — kept outside the try so the finally block can always find
  // them for cleanup.
  String? path;
  Directory? dir;
  try {
    final raw = (account.accountName ?? '').trim();
    final base = raw.isEmpty ? '${account.steamId}' : raw;
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(account.toExportJson(includePassword: includePassword));
    // This file is plaintext: shared_secret, identity_secret, revocation code
    // and the Steam session token. The system temp dir is world-readable on
    // Linux (/tmp or $TMPDIR) and `$accountName.maFile` is guessable from the
    // account name, so another local user could both *predict* the path and
    // read it during the share, or pre-plant a symlink there.
    //
    // Both problems go away by putting it in a fresh directory with an
    // unguessable name: nothing can pre-exist at a random path, and the 0700
    // on the directory keeps the file unreadable regardless of the file's own
    // umask-derived mode. Dart cannot pass a mode to Directory.create, so the
    // chmod follows creation — the window that leaves open is harmless
    // precisely because the name is not guessable.
    //
    // Android is unaffected either way (getTemporaryDirectory is the
    // app-private cache dir), but there is no reason to special-case it.
    final tmpRoot = await getTemporaryDirectory();
    final jail = Directory('${tmpRoot.path}/export-${secureRandomHex(16)}');
    await jail.create(recursive: true);
    dir = jail;
    if (!Platform.isWindows) {
      // Best-effort: on a platform without chmod the random name still stands.
      try {
        await Process.run('chmod', ['700', jail.path]);
      } catch (_) {}
    }
    path = '${jail.path}/$safe.maFile';
    await File(path).writeAsString(json);
    // Share is asynchronous on every platform; we must await its result
    // before deleting, or the receiving app may not have finished reading
    // the file yet.
    await Share.shareXFiles([XFile(path)], subject: '$safe.maFile');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  } finally {
    // This maFile is plaintext (Steam session token, shared_secret…). Never
    // leave it behind in the temp dir — clean it up whether the share sheet
    // succeeded, was cancelled, or the export itself threw. Remove the whole
    // private directory, so a rename or a second file inside it cannot
    // survive either.
    if (dir != null) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {
        // Best-effort cleanup; a failure here shouldn't mask the export's
        // own success/failure, which has already been reported above.
      }
    }
  }
}
