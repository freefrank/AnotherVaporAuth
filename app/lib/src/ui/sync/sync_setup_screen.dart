import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/sync_providers.dart';
import '../../app/theme.dart';
import '../../core/channel.dart';
import '../../core/sync/http_policy.dart';
import '../../core/sync/sync_payload.dart';
import '../../core/sync/sync_transport.dart';
import '../../services/sync/sync_config_store.dart';
import '../../services/sync/sync_engine.dart';
import '../../services/sync/sync_setup.dart';
import '../widgets/ava_panel.dart';
import '../widgets/hold_button.dart';
import '../widgets/scanline_overlay.dart';

/// Setup wizard for account-library sync (spec §UX): backend → server →
/// passphrase → first-merge preview → done. Nothing is saved and nothing on
/// the remote is touched until the preview is confirmed.
class SyncSetupScreen extends ConsumerStatefulWidget {
  const SyncSetupScreen({super.key});

  @override
  ConsumerState<SyncSetupScreen> createState() => _SyncSetupScreenState();
}

enum _Step { backend, server, passphrase, preview, done }

class _SyncSetupScreenState extends ConsumerState<SyncSetupScreen> {
  _Step _step = _Step.backend;

  // Server step.
  final _url = TextEditingController();
  final _folder = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _testing = false;
  String? _serverError;

  // Accumulated as the user works through the dialogs.
  final Map<String, String> _pinnedCerts = {};
  final Set<String> _httpOverrides = {};
  bool _conditionalSupported = true;

  // Learned from the probe.
  RemoteInspection? _remote;

  // Passphrase step.
  final _passphrase = TextEditingController();
  final _passphraseConfirm = TextEditingController();
  bool _verifying = false;
  String? _passphraseError;

  // Preview step.
  SyncPreview? _preview;
  bool _starting = false;

  @override
  void dispose() {
    _url.dispose();
    _folder.dispose();
    _username.dispose();
    _password.dispose();
    _passphrase.dispose();
    _passphraseConfirm.dispose();
    super.dispose();
  }

  SyncConfig _draftConfig() => SyncConfig(
        url: _effectiveUrl(),
        username: _username.text.trim(),
        deviceName: _defaultDeviceName(),
        syncPasswords: _remote?.exists == true
            ? (_remote?.includePasswords ?? true)
            : true,
        passphraseEpoch: _remote?.sidecar?.passphraseEpoch ?? 1,
        httpOverrides: {..._httpOverrides},
        pinnedCerts: {..._pinnedCerts},
        conditionalUnsupported: !_conditionalSupported,
      );

  String _normalizedUrl() {
    var text = _url.text.trim();
    // No scheme typed → assume https. Plain http stays a deliberate act:
    // the user has to type it out, and then still passes the policy gates.
    if (text.isNotEmpty && !text.contains('://')) text = 'https://$text';
    if (text.isNotEmpty && !text.endsWith('/')) text = '$text/';
    return text;
  }

  /// The URL the library actually lives at: base URL plus the optional
  /// folder. Empty folder = the URL as-is; a name (or a/b path) is appended
  /// segment-encoded, and the connection test creates it when missing.
  String _effectiveUrl() {
    var url = _normalizedUrl();
    final folder = _folder.text.trim().replaceAll(r'\', '/');
    for (final seg in folder.split('/')) {
      final s = seg.trim();
      if (s.isEmpty || s == '.' || s == '..') continue;
      url = '$url${Uri.encodeComponent(s)}/';
    }
    return url;
  }

  static String _defaultDeviceName() {
    try {
      final host = Platform.localHostname;
      if (host.isNotEmpty && host != 'localhost') return host;
    } catch (_) {}
    return Platform.operatingSystem;
  }

  // ─── Server step logic ───────────────────────────────────────────────

  Future<void> _testConnection() async {
    final l = AppLocalizations.of(context);
    // Show the user what will actually be used (scheme + trailing slash).
    final normalized = _normalizedUrl();
    if (normalized != _url.text) _url.text = normalized;
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      setState(() => _serverError = l.syncErrUrl);
      return;
    }

    // HTTP policy gates come before any packet leaves the device.
    if (uri.scheme == 'http' && !_httpOverrides.contains(uri.host)) {
      if (isPrivateHost(uri.host)) {
        final ok = await _confirmDialog(
            l.syncHttpPrivateTitle, l.syncHttpPrivateBody, l.syncContinue);
        if (!ok) return;
      } else {
        final allowed = await _confirmPublicHttp(uri.host);
        if (!allowed) return;
      }
    }

    setState(() {
      _testing = true;
      _serverError = null;
    });
    try {
      await _probeOnce();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _step = _Step.passphrase;
      });
    } on SyncTlsUntrusted catch (e) {
      if (!mounted) return;
      setState(() => _testing = false);
      final trusted = await _confirmDialog(
        l.syncTlsTitle,
        l.syncTlsBody(_groupFingerprint(e.fingerprint)),
        l.syncTlsTrust,
      );
      if (trusted) {
        _pinnedCerts[e.host.toLowerCase()] = e.fingerprint;
        await _testConnection(); // retry with the pin in place
      }
    } on SyncTransportException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _serverError = switch (e) {
          SyncAuthError() => l.syncErrAuth,
          SyncNetworkError() => l.syncErrNetwork(e.message),
          _ => l.syncErrServer(e.message),
        };
      });
    }
  }

  Future<void> _probeOnce() async {
    final transport =
        buildWebDavTransport(_draftConfig(), _password.text);
    try {
      await transport.probe();
      // The folder (when given) is created here, so the conditional-support
      // probe and everything after have somewhere to write.
      await transport.ensureRoot();
      _conditionalSupported = await transport.checkConditionalSupport();
      _remote = await inspectRemote(transport);
    } finally {
      transport.close();
    }
  }

  Future<bool> _confirmPublicHttp(String host) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncHttpPublicTitle),
        content: Text(l.syncHttpPublicBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          HoldToConfirmButton(
            label: l.syncHttpPublicHold,
            color: t.bad,
            holdEnabled: ref.read(holdConfirmProvider),
            hapticsEnabled: ref.read(hapticsProvider),
            onConfirmed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (agreed == true) {
      _httpOverrides.add(host.toLowerCase());
      return true;
    }
    return false;
  }

  Future<bool> _confirmDialog(
      String title, String body, String confirm) async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(body)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirm),
              ),
            ],
          ),
        ) ==
        true;
  }

  static String _groupFingerprint(String hex) {
    final upper = hex.toUpperCase();
    final parts = <String>[];
    for (var i = 0; i + 2 <= upper.length; i += 2) {
      parts.add(upper.substring(i, i + 2));
    }
    return parts.join(':');
  }

  // ─── Passphrase step logic ───────────────────────────────────────────

  Future<void> _submitPassphrase() async {
    final l = AppLocalizations.of(context);
    final phrase = _passphrase.text;
    final existing = _remote?.exists == true;
    if (!existing) {
      if (phrase.length < kSyncPassphraseMinLength) {
        setState(() => _passphraseError = l.syncPassphraseTooShort);
        return;
      }
      if (phrase != _passphraseConfirm.text) {
        setState(() => _passphraseError = l.syncPassphraseMismatch);
        return;
      }
    } else if (phrase.isEmpty) {
      setState(() => _passphraseError = l.syncPassphraseWrong);
      return;
    }

    setState(() {
      _verifying = true;
      _passphraseError = null;
    });
    try {
      if (existing) {
        final transport =
            buildWebDavTransport(_draftConfig(), _password.text);
        try {
          final ok = await verifyRemotePassphrase(
              transport, _remote!.sidecar!, phrase);
          if (!ok) {
            setState(() {
              _verifying = false;
              _passphraseError = l.syncPassphraseWrong;
            });
            return;
          }
        } finally {
          transport.close();
        }
      }
      final accounts =
          ref.read(appControllerProvider).value?.accounts ?? const [];
      _preview = previewFirstSync(
        sidecar: _remote?.sidecar,
        local: accounts,
        includePasswords: _draftConfig().syncPasswords,
      );
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _step = _Step.preview;
      });
    } on SyncTransportException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _passphraseError = l.syncErrServer(e.message);
      });
    }
  }

  // ─── Preview step logic ──────────────────────────────────────────────

  Future<void> _start() async {
    setState(() => _starting = true);
    final engine = ref.read(syncEngineProvider);
    await engine.configStore.saveConfig(_draftConfig());
    await engine.configStore.saveWebdavPassword(_password.text);
    await engine.configStore.savePassphrase(_passphrase.text);
    await engine.syncNow();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _step = _Step.done;
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.syncSetupTitle)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: context.rSafeInsets(all: 16),
              children: [
                _stepHeader(l),
                switch (_step) {
                  _Step.backend => _backendStep(l),
                  _Step.server => _serverStep(l),
                  _Step.passphrase => _passphraseStep(l),
                  _Step.preview => _previewStep(l),
                  _Step.done => _doneStep(l),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(AppLocalizations l) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final index = _step.index + 1;
    return Padding(
      padding: context.rInsets(bottom: 12),
      child: Text(
        '$index / ${_Step.values.length}',
        style: TextStyle(color: t.muted, fontSize: context.r(12.5)),
      ),
    );
  }

  Widget _panel({required String title, String? body, required Widget child}) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return AvaPanel(
      padding: context.rInsets(all: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: t.text, fontSize: context.r(16))),
          if (body != null) ...[
            SizedBox(height: context.r(6)),
            Text(body,
                style: TextStyle(color: t.muted, fontSize: context.r(12.5))),
          ],
          SizedBox(height: context.r(14)),
          child,
        ],
      ),
    );
  }

  Widget _backendStep(AppLocalizations l) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _panel(
      title: l.syncBackendTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backendTile(
            t,
            title: l.syncBackendWebdav,
            subtitle: l.syncBackendWebdavDesc,
            enabled: true,
            onTap: () => setState(() => _step = _Step.server),
          ),
          // Google Drive: play-flavor Pro backend, not yet implemented.
          // Hidden entirely on cn (no Google services in that channel).
          if (avaChannel == AvaChannel.play)
            _backendTile(
              t,
              title: l.syncBackendGdrive,
              subtitle: l.syncBackendGdriveSoon,
              enabled: false,
              onTap: null,
            ),
        ],
      ),
    );
  }

  Widget _backendTile(AvaTokens t,
      {required String title,
      required String subtitle,
      required bool enabled,
      VoidCallback? onTap}) {
    return Padding(
      padding: context.rInsets(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(t.radiusSm),
        child: Container(
          padding: context.rInsets(all: 14),
          decoration: BoxDecoration(
            color: t.panel2,
            borderRadius: BorderRadius.circular(t.radiusSm),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: enabled ? t.text : t.muted,
                            fontSize: context.r(14.5))),
                    SizedBox(height: context.r(3)),
                    Text(subtitle,
                        style: TextStyle(
                            color: t.muted, fontSize: context.r(12))),
                  ],
                ),
              ),
              Icon(enabled ? Icons.chevron_right : Icons.lock_outline,
                  size: context.r(18), color: t.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverStep(AppLocalizations l) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _panel(
      title: l.syncServerTitle,
      body: l.syncServerHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l.syncServerUrlLabel,
              hintText: 'https://…/remote.php/dav/files/you/',
            ),
          ),
          SizedBox(height: context.r(10)),
          TextField(
            controller: _folder,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l.syncServerFolderLabel,
              helperText: l.syncServerFolderHint,
              helperMaxLines: 3,
              hintText: 'ava',
            ),
          ),
          SizedBox(height: context.r(10)),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: InputDecoration(labelText: l.syncServerUserLabel),
          ),
          SizedBox(height: context.r(10)),
          TextField(
            controller: _password,
            obscureText: true,
            decoration:
                InputDecoration(labelText: l.syncServerPasswordLabel),
          ),
          if (_serverError != null) ...[
            SizedBox(height: context.r(10)),
            Text(_serverError!,
                style:
                    TextStyle(color: t.bad, fontSize: context.r(12.5))),
          ],
          SizedBox(height: context.r(14)),
          FilledButton(
            onPressed: _testing ? null : _testConnection,
            child: _testing
                ? SizedBox(
                    width: context.r(16),
                    height: context.r(16),
                    child: const CircularProgressIndicator(strokeWidth: 2))
                : Text(l.syncTestConnection),
          ),
        ],
      ),
    );
  }

  Widget _passphraseStep(AppLocalizations l) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final existing = _remote?.exists == true;
    final phrase = _passphrase.text;
    return _panel(
      title: existing
          ? l.syncPassphraseExistingTitle
          : l.syncPassphraseNewTitle,
      body: existing
          ? l.syncPassphraseExistingBody(_remote?.accountCount ?? 0)
          : l.syncPassphraseNewBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _passphrase,
            obscureText: true,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.syncPassphraseLabel),
          ),
          if (!existing) ...[
            SizedBox(height: context.r(6)),
            _strengthBar(t, phrase),
            SizedBox(height: context.r(10)),
            TextField(
              controller: _passphraseConfirm,
              obscureText: true,
              autocorrect: false,
              decoration:
                  InputDecoration(labelText: l.syncPassphraseConfirmLabel),
            ),
          ],
          if (_passphraseError != null) ...[
            SizedBox(height: context.r(10)),
            Text(_passphraseError!,
                style:
                    TextStyle(color: t.bad, fontSize: context.r(12.5))),
          ],
          SizedBox(height: context.r(14)),
          FilledButton(
            onPressed: _verifying ? null : _submitPassphrase,
            child: _verifying
                ? SizedBox(
                    width: context.r(16),
                    height: context.r(16),
                    child: const CircularProgressIndicator(strokeWidth: 2))
                : Text(l.syncContinue),
          ),
        ],
      ),
    );
  }

  /// Length-driven strength bar. Character classes add a little, but length
  /// dominates on purpose: the remote KDF is SDA's PBKDF2-SHA1/50000 (the
  /// price of SDA compatibility), so the passphrase itself has to carry the
  /// entropy.
  Widget _strengthBar(AvaTokens t, String phrase) {
    var score = (phrase.length / 20).clamp(0.0, 0.7);
    if (phrase.contains(RegExp(r'[A-Z]')) &&
        phrase.contains(RegExp(r'[a-z]'))) {
      score += 0.1;
    }
    if (phrase.contains(RegExp(r'[0-9]'))) score += 0.1;
    if (phrase.contains(RegExp(r'[^A-Za-z0-9]'))) score += 0.1;
    score = phrase.length < kSyncPassphraseMinLength
        ? score.clamp(0.0, 0.3)
        : score;
    final color = score < 0.4
        ? t.bad
        : score < 0.7
            ? t.warn
            : t.good;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.r(3)),
      child: LinearProgressIndicator(
        value: score.clamp(0.05, 1.0),
        minHeight: context.r(5),
        backgroundColor: t.panel2,
        color: color,
      ),
    );
  }

  Widget _previewStep(AppLocalizations l) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final p = _preview!;
    final empty = p.pulls == 0 && p.pushes == 0 && p.conflicts == 0;
    return _panel(
      title: l.syncPreviewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (empty)
            Text(l.syncPreviewEmpty,
                style: TextStyle(color: t.muted, fontSize: context.r(13)))
          else ...[
            if (p.pulls > 0)
              _previewRow(t, Icons.download_outlined,
                  l.syncPreviewPull(p.pulls)),
            if (p.pushes > 0)
              _previewRow(
                  t, Icons.upload_outlined, l.syncPreviewPush(p.pushes)),
            if (p.conflicts > 0)
              _previewRow(t, Icons.call_split,
                  l.syncPreviewConflict(p.conflicts)),
          ],
          SizedBox(height: context.r(14)),
          FilledButton(
            onPressed: _starting ? null : _start,
            child: _starting
                ? SizedBox(
                    width: context.r(16),
                    height: context.r(16),
                    child: const CircularProgressIndicator(strokeWidth: 2))
                : Text(l.syncStart),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(AvaTokens t, IconData icon, String text) {
    return Padding(
      padding: context.rInsets(v: 5),
      child: Row(
        children: [
          Icon(icon, size: context.r(18), color: t.accent),
          SizedBox(width: context.r(10)),
          Expanded(
            child: Text(text,
                style: TextStyle(color: t.text, fontSize: context.r(13.5))),
          ),
        ],
      ),
    );
  }

  Widget _doneStep(AppLocalizations l) {
    final status = ref.watch(syncStatusProvider);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return _panel(
      title: l.syncDoneTitle,
      body: l.syncDoneBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status.conflicts.isNotEmpty)
            Padding(
              padding: context.rInsets(bottom: 10),
              child: Text(
                l.syncStatusConflicts(status.conflicts.length),
                style:
                    TextStyle(color: t.warn, fontSize: context.r(12.5)),
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.syncDone),
          ),
        ],
      ),
    );
  }
}
