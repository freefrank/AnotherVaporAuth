import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/sync_providers.dart';
import '../../app/theme.dart';
import '../../core/sync/sync_payload.dart';
import '../../core/sync/sync_planner.dart';
import '../../services/sync/sync_config_store.dart';
import '../../services/sync/sync_engine.dart';
import '../../services/sync/sync_trash.dart';
import '../widgets/ava_panel.dart';
import '../widgets/hold_button.dart';
import '../widgets/scanline_overlay.dart';
import 'sync_setup_screen.dart';

/// Sync detail page: status, the options table, conflicts, trash, and the
/// destructive actions — everything after setup. Spec §UX rule: sync is the
/// library's shadow, never its gate; nothing here blocks account operations.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  SyncConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config =
        await ref.read(syncEngineProvider).configStore.loadConfig();
    if (mounted) setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = ref.watch(syncStatusProvider);
    final config = _config;

    if (!status.configured || config == null) {
      // Disconnected (possibly just now, from this very screen).
      return Scaffold(
        appBar: AppBar(title: Text(l.syncTitle)),
        body: Center(
          child: config == null && status.configured
              ? const CircularProgressIndicator()
              : FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => const SyncSetupScreen()),
                  ),
                  child: Text(l.syncSetUp),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.syncTitle)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: context.rSafeInsets(all: 16),
              children: [
                _statusCard(l, status, config),
                if (status.conflicts.isNotEmpty) _conflictsCard(l, status),
                _optionsCard(l, status, config),
                _dataCard(l, status),
                _dangerCard(l, status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Status ──────────────────────────────────────────────────────────

  Widget _statusCard(
      AppLocalizations l, SyncEngineStatus status, SyncConfig config) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final host = Uri.tryParse(config.url)?.host ?? config.url;

    final (icon, color, line) = switch (status) {
      SyncEngineStatus(syncing: true) => (
          Icons.sync,
          t.accent,
          l.syncStatusSyncing
        ),
      SyncEngineStatus(needsPassphrase: true) => (
          Icons.key_off_outlined,
          t.warn,
          l.syncNeedsPassphrase
        ),
      SyncEngineStatus(hasError: true) => (
          Icons.error_outline,
          t.bad,
          _errorLine(l, status)
        ),
      SyncEngineStatus(conflicts: final c) when c.isNotEmpty => (
          Icons.call_split,
          t.warn,
          l.syncStatusConflicts(c.length)
        ),
      _ => (Icons.check_circle_outline, t.good, l.syncStatusOk),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.r(20), color: color),
              SizedBox(width: context.r(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host,
                        style: TextStyle(
                            color: t.text, fontSize: context.r(15))),
                    SizedBox(height: context.r(3)),
                    Text(line,
                        style: TextStyle(
                            color: color, fontSize: context.r(12.5))),
                    SizedBox(height: context.r(3)),
                    Text(
                      l.syncLastSync(status.lastSyncAt == null
                          ? l.syncNever
                          : _formatTime(status.lastSyncAt!)),
                      style: TextStyle(
                          color: t.muted, fontSize: context.r(12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status.needsPassphrase) ...[
            SizedBox(height: context.r(12)),
            OutlinedButton(
              onPressed: _reenterPassphrase,
              child: Text(l.syncEnterPassphrase),
            ),
          ],
          if (status.conditionalUnsupported) ...[
            SizedBox(height: context.r(10)),
            Text(l.syncConditionalWarn,
                style: TextStyle(color: t.warn, fontSize: context.r(12))),
          ],
        ],
      ),
    );
  }

  String _errorLine(AppLocalizations l, SyncEngineStatus status) {
    final detail = status.errorDetail ?? '';
    return switch (status.errorKind) {
      SyncErrorKind.auth => l.syncErrAuth,
      SyncErrorKind.network => l.syncErrNetwork(detail),
      SyncErrorKind.tls => l.syncErrTls,
      SyncErrorKind.passphrase => l.syncNeedsPassphrase,
      _ => l.syncErrServer(detail),
    };
  }

  static String _formatTime(DateTime time) {
    final v = time.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${v.year}-${two(v.month)}-${two(v.day)} '
        '${two(v.hour)}:${two(v.minute)}';
  }

  Future<void> _reenterPassphrase() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final phrase = await _promptText(
      title: l.syncEnterPassphrase,
      label: l.syncPassphraseLabel,
      obscure: true,
    );
    if (phrase == null || phrase.isEmpty) return;
    final ok =
        await ref.read(syncEngineProvider).providePassphrase(phrase);
    if (!ok && mounted) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.syncPassphraseWrong)));
    }
  }

  // ─── Conflicts ───────────────────────────────────────────────────────

  Widget _conflictsCard(AppLocalizations l, SyncEngineStatus status) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.syncConflictsTitle,
              style: TextStyle(color: t.text, fontSize: context.r(15))),
          SizedBox(height: context.r(4)),
          Text(l.syncConflictTrashNote,
              style: TextStyle(color: t.muted, fontSize: context.r(12))),
          SizedBox(height: context.r(8)),
          for (final c in status.conflicts) _conflictRow(l, t, c),
        ],
      ),
    );
  }

  Widget _conflictRow(
      AppLocalizations l, AvaTokens t, SyncConflictItem c) {
    final kindLine = switch (c.kind) {
      SyncConflictKind.editEdit => l.syncConflictEditEdit,
      SyncConflictKind.editDelete => l.syncConflictEditDelete,
      SyncConflictKind.deleteEdit => l.syncConflictDeleteEdit,
    };
    return InkWell(
      onTap: () => _resolveConflict(c),
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Padding(
        padding: context.rInsets(v: 8),
        child: Row(
          children: [
            Icon(Icons.call_split, size: context.r(18), color: t.warn),
            SizedBox(width: context.r(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.accountName ?? '${c.steamId}',
                      style: TextStyle(
                          color: t.text, fontSize: context.r(14))),
                  Text(kindLine,
                      style: TextStyle(
                          color: t.muted, fontSize: context.r(12))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: context.r(16), color: t.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveConflict(SyncConflictItem c) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final keepLocal = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.accountName ?? '${c.steamId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _conflictSide(
              ctx,
              t,
              title: l.syncConflictLocalSide,
              payload: c.localPayload,
              deletedLine:
                  c.kind == SyncConflictKind.deleteEdit ? l.syncDeleted : null,
            ),
            SizedBox(height: context.r(10)),
            _conflictSide(
              ctx,
              t,
              title: l.syncConflictRemoteSide,
              payload: c.remotePayload,
              deletedLine: c.kind == SyncConflictKind.editDelete
                  ? l.syncDeleted
                  : null,
            ),
            SizedBox(height: context.r(12)),
            Text(l.syncConflictTrashNote,
                style: TextStyle(color: t.muted, fontSize: context.r(11.5))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.syncConflictKeepRemote),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.syncConflictKeepLocal),
          ),
        ],
      ),
    );
    if (keepLocal == null) return;
    await ref
        .read(syncEngineProvider)
        .resolveConflict(c.steamId, keepLocal: keepLocal);
  }

  Widget _conflictSide(BuildContext context, AvaTokens t,
      {required String title,
      Map<String, dynamic>? payload,
      String? deletedLine}) {
    final name = payload?['account_name'] as String?;
    final hasPassword = (payload?['password'] as String?)?.isNotEmpty == true;
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: context.rInsets(all: 10),
      decoration: BoxDecoration(
        color: t.panel2,
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border.all(color: t.borderColor, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: t.muted, fontSize: context.r(11.5))),
          SizedBox(height: context.r(3)),
          if (deletedLine != null)
            Text(deletedLine,
                style: TextStyle(color: t.bad, fontSize: context.r(13)))
          else ...[
            Text(name ?? '—',
                style: TextStyle(color: t.text, fontSize: context.r(13.5))),
            Text(
              hasPassword
                  ? l.syncConflictHasPassword
                  : l.syncConflictNoPassword,
              style: TextStyle(color: t.muted, fontSize: context.r(11.5)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Options ─────────────────────────────────────────────────────────

  Widget _optionsCard(
      AppLocalizations l, SyncEngineStatus status, SyncConfig config) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _optionRow(
            t,
            title: l.syncAutoTitle,
            description: l.syncAutoDesc,
            trailing: Switch(
              value: config.autoSync,
              onChanged: (v) async {
                await ref.read(syncEngineProvider).setAutoSync(v);
                await _loadConfig();
              },
            ),
          ),
          _optionRow(
            t,
            title: l.syncPasswordsTitle,
            description: l.syncPasswordsDesc,
            trailing: Switch(
              value: config.syncPasswords,
              onChanged: (v) async {
                await ref.read(syncEngineProvider).setSyncPasswords(v);
                await _loadConfig();
              },
            ),
          ),
          _optionRow(
            t,
            title: l.syncAppSettingsTitle,
            description: l.syncAppSettingsDesc,
            trailing: Switch(
              value: config.syncSettings,
              onChanged: (v) async {
                await ref.read(syncEngineProvider).setSyncSettings(v);
                await _loadConfig();
              },
            ),
          ),
          SizedBox(height: context.r(6)),
          Row(
            children: [
              FilledButton.icon(
                onPressed: status.syncing
                    ? null
                    : () => ref.read(syncEngineProvider).syncNow(),
                icon: Icon(Icons.sync, size: context.r(16)),
                label: Text(l.syncNowButton),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionRow(AvaTokens t,
      {required String title,
      required String description,
      required Widget trailing}) {
    return Padding(
      padding: context.rInsets(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: t.text, fontSize: context.r(14))),
                SizedBox(height: context.r(2)),
                Text(description,
                    style: TextStyle(
                        color: t.muted, fontSize: context.r(11.5))),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // ─── Data: view remote / trash ───────────────────────────────────────

  Widget _dataCard(AppLocalizations l, SyncEngineStatus status) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _actionRow(t, Icons.cloud_outlined, l.syncViewRemote, _viewRemote),
          _actionRow(
              t, Icons.delete_outline, l.syncTrashTitle, _viewTrash),
        ],
      ),
    );
  }

  Widget _actionRow(
      AvaTokens t, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Padding(
        padding: context.rInsets(v: 9),
        child: Row(
          children: [
            Icon(icon, size: context.r(18), color: t.accent),
            SizedBox(width: context.r(12)),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: t.text, fontSize: context.r(14))),
            ),
            Icon(Icons.chevron_right, size: context.r(16), color: t.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _viewRemote() async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final messenger = ScaffoldMessenger.of(context);
    final SyncSidecar? sidecar;
    try {
      sidecar = await ref.read(syncEngineProvider).fetchRemoteSidecar();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.syncErrServer('$e'))));
      return;
    }
    if (!mounted) return;
    final localNames = {
      for (final a
          in ref.read(appControllerProvider).value?.accounts ?? const [])
        a.steamId: a.accountName
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncViewRemote),
        content: SizedBox(
          width: 380,
          child: sidecar == null || sidecar.accounts.isEmpty
              ? Text(l.syncRemoteEmpty)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in sidecar.accounts.entries)
                      Padding(
                        padding: context.rInsets(v: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                localNames[e.key] ?? '${e.key}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: t.text,
                                    fontSize: context.r(13.5)),
                              ),
                            ),
                            Text('r${e.value.rev}',
                                style: TextStyle(
                                    color: t.muted,
                                    fontSize: context.r(12))),
                          ],
                        ),
                      ),
                    if (sidecar.devices.isNotEmpty) ...[
                      SizedBox(height: context.r(10)),
                      Text(l.syncRemoteDevices,
                          style: TextStyle(
                              color: t.muted, fontSize: context.r(12))),
                      for (final d in sidecar.devices.values)
                        Text(
                          '${d.name} · ${d.lastSyncAt ?? '—'}',
                          style: TextStyle(
                              color: t.muted, fontSize: context.r(11.5)),
                        ),
                    ],
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _viewTrash() async {
    final engine = ref.read(syncEngineProvider);
    final entries = await engine.trash.list();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _TrashDialog(entries: entries),
    );
  }

  // ─── Danger zone ─────────────────────────────────────────────────────

  Widget _dangerCard(AppLocalizations l, SyncEngineStatus status) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _actionRow(
              t, Icons.password, l.syncChangePassphrase, _changePassphrase),
          _actionRow(t, Icons.link_off, l.syncDisconnect, _disconnect),
        ],
      ),
    );
  }

  Future<void> _changePassphrase() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final phrase = await _promptNewPassphrase();
    if (phrase == null) return;
    final error =
        await ref.read(syncEngineProvider).changePassphrase(phrase);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error == null
          ? l.syncPassphraseChanged
          : l.syncPassphraseChangeFailed(error)),
    ));
  }

  Future<String?> _promptNewPassphrase() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.syncChangePassphrase),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: l.syncPassphraseLabel),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.syncPassphraseConfirmLabel,
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length < kSyncPassphraseMinLength) {
                  setDialogState(() => error = l.syncPassphraseTooShort);
                  return;
                }
                if (controller.text != confirm.text) {
                  setDialogState(() => error = l.syncPassphraseMismatch);
                  return;
                }
                Navigator.pop(ctx, controller.text);
              },
              child: Text(l.commonOk),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    confirm.dispose();
    return result;
  }

  Future<void> _disconnect() async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final engine = ref.read(syncEngineProvider);
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncDisconnect),
        content: Text(l.syncDisconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.syncDisconnectKeep),
          ),
          HoldToConfirmButton(
            label: l.syncDisconnectDeleteHold,
            color: t.bad,
            holdEnabled: ref.read(holdConfirmProvider),
            hapticsEnabled: ref.read(hapticsProvider),
            onConfirmed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await engine.disconnect(deleteRemote: choice);
    if (mounted) Navigator.of(context).pop();
  }

  // ─── Shared bits ─────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Padding(
        padding: context.rInsets(bottom: 12),
        child: AvaPanel(
          padding: context.rInsets(all: 16),
          child: child,
        ),
      );

  Future<String?> _promptText(
      {required String title,
      required String label,
      bool obscure = false}) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.commonOk),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

/// Trash list with per-entry restore. Restore decrypts with the stored
/// passphrase and funnels through the normal import path (same merge rules).
class _TrashDialog extends ConsumerStatefulWidget {
  final List<SyncTrashEntry> entries;
  const _TrashDialog({required this.entries});

  @override
  ConsumerState<_TrashDialog> createState() => _TrashDialogState();
}

class _TrashDialogState extends ConsumerState<_TrashDialog> {
  late List<SyncTrashEntry> _entries = widget.entries;
  bool _busy = false;

  Future<void> _restore(SyncTrashEntry entry) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final engine = ref.read(syncEngineProvider);
      final passphrase = await engine.configStore.loadPassphrase();
      final payload =
          passphrase == null ? null : entry.decrypt(passphrase);
      if (payload == null) {
        messenger.showSnackBar(
            SnackBar(content: Text(l.syncTrashRestoreFailed)));
        return;
      }
      await ref
          .read(appControllerProvider.notifier)
          .importMaFile(jsonEncode(payload), sourceName: 'sync-trash');
      await engine.trash.delete(entry.filename);
      setState(
          () => _entries = [..._entries]..removeWhere((e) => e == entry));
      messenger
          .showSnackBar(SnackBar(content: Text(l.syncTrashRestored)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return AlertDialog(
      title: Text(l.syncTrashTitle),
      content: SizedBox(
        width: 380,
        child: _entries.isEmpty
            ? Text(l.syncTrashEmpty)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final e in _entries)
                    Padding(
                      padding: context.rInsets(v: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(e.accountName ?? '${e.steamId}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: t.text,
                                        fontSize: context.r(13.5))),
                                Text(
                                  '${_reasonLine(l, e.reason)} · '
                                  '${e.deletedAt.toLocal().toString().substring(0, 16)}',
                                  style: TextStyle(
                                      color: t.muted,
                                      fontSize: context.r(11.5)),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _restore(e),
                            child: Text(l.syncTrashRestore),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonOk),
        ),
      ],
    );
  }

  String _reasonLine(AppLocalizations l, SyncTrashReason reason) =>
      switch (reason) {
        SyncTrashReason.remoteDelete => l.syncTrashReasonRemoteDelete,
        SyncTrashReason.conflictLocal ||
        SyncTrashReason.conflictRemote =>
          l.syncTrashReasonConflict,
      };
}
