import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../services/feedback_service.dart';
import '../services/debug_log.dart';
import 'debug_log_screen.dart';
import 'widgets/pin_field.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/ava_panel.dart';

const _repoUrl = 'https://github.com/freefrank/AnotherVaporAuth';
const _authorUrl = 'https://dotslash.pro';
const _licenseUrl =
    'https://github.com/freefrank/AnotherVaporAuth/blob/main/LICENSE';
const _privacyUrl =
    'https://github.com/freefrank/AnotherVaporAuth/blob/main/PRIVACY.md';

/// Design screen 08 — settings. Each option is a panel card with a title, a
/// short description and its control. Theme + language are selectable chips.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final data = ref.watch(appControllerProvider).value;
    final manifest = data?.store.manifest;
    final skin = ref.watch(skinProvider);
    final mode = ref.watch(brightnessModeProvider);
    final locale = ref.watch(localeProvider);

    if (manifest == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Persist manifest toggles in place — invalidating the app controller here
    // would re-run the encrypted bootstrap and lock the app again.
    Future<void> save() =>
        ref.read(appControllerProvider.notifier).saveSettings();

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: context.rInsets(all: 16),
              children: [
                // Encryption
                _Card(
                  title: l.settingsEncryption,
                  description: l.settingsEncryptionDesc,
                  trailing: OutlinedButton(
                    onPressed: () => _changePasskey(context, ref),
                    child: Text((data?.encrypted ?? false)
                        ? l.settingsChange
                        : l.settingsSet),
                  ),
                ),
                // Biometric / device-credential unlock
                const _BiometricCard(),
                // Auto-confirm. Only the market-listing default is wired up —
                // the legacy SDA "periodic checking / check all / auto-confirm
                // trades" toggles were file-format fields with no behaviour in
                // AVA, so they've been removed rather than mislead. The manifest
                // fields stay for .NET maFile round-trip compatibility. A single
                // self-describing toggle needs no separate group header.
                _Card(
                  title: l.settingsAutoConfirmMarket,
                  description: l.settingsAutoConfirmMarketDesc,
                  trailing: Switch(
                    value: manifest.autoConfirmMarketTransactions,
                    onChanged: (v) {
                      manifest.autoConfirmMarketTransactions = v;
                      save();
                    },
                  ),
                ),
                // Appearance (light/dark for the plain look)
                _Card(
                  title: l.settingsAppearance,
                  description: l.settingsAppearanceDesc,
                  child: Wrap(
                    spacing: context.r(8),
                    children: [
                      _choice(context, t, l.themeSystem,
                          mode == AvaBrightnessMode.system,
                          () => ref
                              .read(brightnessModeProvider.notifier)
                              .setMode(AvaBrightnessMode.system)),
                      _choice(context, t, l.themeDark,
                          mode == AvaBrightnessMode.dark,
                          () => ref
                              .read(brightnessModeProvider.notifier)
                              .setMode(AvaBrightnessMode.dark)),
                      _choice(context, t, l.themeLight,
                          mode == AvaBrightnessMode.light,
                          () => ref
                              .read(brightnessModeProvider.notifier)
                              .setMode(AvaBrightnessMode.light)),
                    ],
                  ),
                ),
                // Skins (styled looks; override appearance while active)
                _Card(
                  title: l.settingsSkin,
                  description: l.settingsSkinDesc,
                  child: Wrap(
                    spacing: context.r(8),
                    children: [
                      _choice(context, t, l.skinNone, skin == AvaSkin.none,
                          () => ref
                              .read(skinProvider.notifier)
                              .setSkin(AvaSkin.none)),
                      _choice(context, t, l.themeNeon, skin == AvaSkin.neon,
                          () => ref
                              .read(skinProvider.notifier)
                              .setSkin(AvaSkin.neon)),
                      _choice(context, t, l.themePixel, skin == AvaSkin.pixel,
                          () => ref
                              .read(skinProvider.notifier)
                              .setSkin(AvaSkin.pixel)),
                    ],
                  ),
                ),
                // Language
                _Card(
                  title: l.settingsLanguage,
                  child: Wrap(
                    spacing: context.r(8),
                    children: [
                      _choice(context, t, l.settingsLanguageSystem,
                          locale == null,
                          () => ref
                              .read(localeProvider.notifier)
                              .setLocale(null)),
                      _choice(context, t, 'English',
                          locale?.languageCode == 'en',
                          () => ref
                              .read(localeProvider.notifier)
                              .setLocale(const Locale('en'))),
                      _choice(context, t, '简体中文',
                          locale?.languageCode == 'zh',
                          () => ref
                              .read(localeProvider.notifier)
                              .setLocale(const Locale('zh'))),
                    ],
                  ),
                ),
                // Replay the first-run gesture tutorial (touch platforms only —
                // desktop uses the right-click context menu instead).
                if (switch (Theme.of(context).platform) {
                  TargetPlatform.android ||
                  TargetPlatform.iOS ||
                  TargetPlatform.fuchsia =>
                    true,
                  _ => false,
                })
                  _Card(
                    title: l.settingsTutorial,
                    description: l.settingsTutorialDesc,
                    trailing: OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(settingsStoreProvider)
                            .resetTutorialSeen();
                        ref.read(tutorialReplayProvider.notifier).bump();
                        // Back to home, where the walkthrough starts.
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text(l.settingsTutorialReplay),
                    ),
                  ),
                // Debug log (network trace for diagnosing the Steam flows)
                _Card(
                  title: l.debugLog,
                  description: l.debugLogDesc,
                  trailing: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DebugLogScreen()),
                    ),
                    child: Text(l.commonOpen),
                  ),
                ),
                // Feedback (user-initiated relay to the developer's mailbox)
                _Card(
                  title: l.feedbackTitle,
                  description: l.feedbackDesc,
                  trailing: OutlinedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const _FeedbackDialog(),
                    ),
                    child: Text(l.feedbackSend),
                  ),
                ),
                // About
                _Card(
                  title: l.settingsAbout,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'AVA · AnotherVaporAuth  v${ref.watch(appVersionProvider).value ?? '…'}',
                          style:
                              TextStyle(color: t.text, fontSize: context.r(14))),
                      SizedBox(height: context.r(4)),
                      Text(l.aboutTagline,
                          style: TextStyle(
                              color: t.muted, fontSize: context.r(12.5))),
                      SizedBox(height: context.r(10)),
                      _aboutRow(context, t, Icons.code, l.aboutSourceCode,
                          'github.com/freefrank/AnotherVaporAuth',
                          () => _openUrl(_repoUrl), external: true),
                      _aboutRow(context, t, Icons.person_outline, l.aboutAuthor,
                          'dotslash.pro', () => _openUrl(_authorUrl),
                          external: true),
                      _aboutRow(context, t, Icons.gavel_outlined,
                          l.aboutLicense, 'MIT', () => _openUrl(_licenseUrl),
                          external: true),
                      _aboutRow(
                          context,
                          t,
                          Icons.privacy_tip_outlined,
                          l.aboutPrivacy,
                          null,
                          () => _openUrl(_privacyUrl),
                          external: true),
                      _aboutRow(
                        context,
                        t,
                        Icons.inventory_2_outlined,
                        l.aboutLicenses,
                        null,
                        () => showLicensePage(
                          context: context,
                          applicationName: 'AVA · AnotherVaporAuth',
                          applicationVersion:
                              'v${ref.read(appVersionProvider).value ?? ''}',
                          applicationLegalese: '© 2026 freefrank · MIT',
                        ),
                      ),
                      SizedBox(height: context.r(10)),
                      Text(l.aboutCredits,
                          style: TextStyle(
                              color: t.text, fontSize: context.r(13.5))),
                      SizedBox(height: context.r(4)),
                      Text(l.aboutCreditsBody,
                          style: TextStyle(
                              color: t.muted, fontSize: context.r(12.5))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser / launch failed — ignore */}
  }

  Widget _aboutRow(BuildContext context, AvaTokens t, IconData icon,
      String label, String? value, VoidCallback onTap,
      {bool external = false}) {
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
            if (value != null)
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: t.muted, fontSize: context.r(12.5))),
              ),
            SizedBox(width: context.r(6)),
            Icon(external ? Icons.open_in_new : Icons.chevron_right,
                size: context.r(16), color: t.muted),
          ],
        ),
      ),
    );
  }


  Widget _choice(BuildContext context, AvaTokens t, String label, bool selected,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Container(
        padding: context.rInsets(h: 16, v: 9),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.panel2,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: Border.all(
              color: selected ? t.accent : t.borderColor, width: t.borderWidth),
          boxShadow: selected ? t.glowShadow(blur: context.r(10)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF06060F) : t.text,
            fontSize: context.r(13),
          ),
        ),
      ),
    );
  }

  Future<void> _changePasskey(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final data = ref.read(appControllerProvider).value;
    if (data == null) return;

    final entered = await showDialog<({String old, String next})>(
      context: context,
      builder: (_) => _PasskeyDialog(askOld: data.encrypted),
    );

    if (entered == null) return;
    final newKey = entered.next;
    if (newKey.length != 6) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.pinSixDigits)));
      }
      return;
    }
    final oldKey = entered.old.isEmpty ? null : entered.old;
    final success = await ref
        .read(appControllerProvider.notifier)
        .changePasskey(data.encrypted ? oldKey : null, newKey);
    if (success) {
      // The stored biometric passkey is now stale — clear it so the user
      // re-enables with the new passkey.
      await ref.read(biometricUnlockProvider).disable();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? l.commonOk : l.unlockInvalid)),
      );
    }
  }
}

/// PIN change dialog. Owns its text controllers so they are disposed with the
/// route; pops the entered `(old, next)` pair on OK, null on cancel.
/// Compose-and-send dialog for in-app feedback. Shows exactly what metadata
/// travels with the message; nothing is sent until the user presses send.
class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog();

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  String _meta = '';
  bool _sending = false;
  bool _attachLog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final code = Localizations.localeOf(context).languageCode;
      final meta = await FeedbackService.meta(code);
      if (mounted) setState(() => _meta = meta);
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await FeedbackService.send(
        message: _message.text.trim(),
        contact: _contact.text.trim(),
        meta: _meta,
        log: _attachLog ? _logTail() : null,
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.feedbackSent)));
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        messenger.showSnackBar(SnackBar(content: Text(l.feedbackFailed)));
      }
    }
  }

  /// First tick shows a one-time consent notice describing what the log
  /// contains; the agreement persists across sessions.
  Future<void> _onAttachLogChanged(bool? v) async {
    if (v != true) {
      setState(() => _attachLog = false);
      return;
    }
    final settings = ref.read(settingsStoreProvider);
    if (!await settings.loadLogConsentShown()) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final agreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.feedbackAttachLog),
          content: Text(l.feedbackLogConsentBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.feedbackLogConsentAgree),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      await settings.saveLogConsentShown();
    }
    if (mounted) setState(() => _attachLog = true);
  }

  /// Last chunk of the in-app debug log (kept within the relay's size cap).
  String _logTail() {
    final d = DebugLog.instance.dump();
    return d.length > 12000 ? d.substring(d.length - 12000) : d;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return AlertDialog(
      title: Text(l.feedbackTitle),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _message,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.feedbackMessageLabel,
                hintText: l.feedbackMessageHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l.feedbackContactLabel,
                hintText: l.feedbackContactHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _attachLog,
              onChanged: _sending ? null : _onAttachLogChanged,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.feedbackAttachLog,
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(l.feedbackAttachLogHint,
                  style: TextStyle(color: t.muted, fontSize: 11)),
            ),
            const SizedBox(height: 4),
            Text(
              l.feedbackAttachNote(_meta),
              style: TextStyle(color: t.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed:
              _sending || _message.text.trim().isEmpty ? null : _send,
          child: _sending
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.feedbackSend),
        ),
      ],
    );
  }
}

class _PasskeyDialog extends StatefulWidget {
  final bool askOld;
  const _PasskeyDialog({required this.askOld});

  @override
  State<_PasskeyDialog> createState() => _PasskeyDialogState();
}

class _PasskeyDialogState extends State<_PasskeyDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    if (_new.text.length != 6) {
      setState(() => _error = l.pinSixDigits);
      return;
    }
    // Confirm the new PIN before committing — a mistyped new PIN would
    // re-wrap the vault under a value the user can't reproduce (lockout).
    if (_confirm.text != _new.text) {
      setState(() => _error = l.pinMismatch);
      return;
    }
    Navigator.pop(context, (old: _old.text, next: _new.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.pinChangeTitle),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.askOld) ...[
              PinField(
                  controller: _old, label: l.pinCurrentLabel, autofocus: true),
              const SizedBox(height: 12),
            ],
            PinField(
              controller: _new,
              label: l.pinNewLabel,
              autofocus: !widget.askOld,
              onCompleted: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            PinField(
              controller: _confirm,
              label: l.pinConfirmLabel,
              errorText: _error,
              onCompleted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(l.commonOk)),
      ],
    );
  }
}

/// Toggle for system-credential (biometric / device PIN) unlock. Hidden when the
/// device has no biometrics/lock set up. Enabling stores the current encryption
/// passkey in the keystore (the store must be encrypted + unlocked first).
class _BiometricCard extends ConsumerStatefulWidget {
  const _BiometricCard();

  @override
  ConsumerState<_BiometricCard> createState() => _BiometricCardState();
}

class _BiometricCardState extends ConsumerState<_BiometricCard> {
  bool _supported = false;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = ref.read(biometricUnlockProvider);
    final supported = await bio.isSupported;
    final enabled = await bio.isEnabled;
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    final l = AppLocalizations.of(context);
    final bio = ref.read(biometricUnlockProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (!value) {
      await bio.disable();
      if (mounted) setState(() => _enabled = false);
      return;
    }
    final passKey = ref.read(appControllerProvider).value?.passKey;
    if (passKey == null || passKey.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.settingsBiometricNeedPasskey)));
      return;
    }
    final ok = await bio.enable(passKey, l.unlockBiometricReason);
    if (!mounted || !ok) return;
    setState(() => _enabled = true);
    messenger
        .showSnackBar(SnackBar(content: Text(l.settingsBiometricEnabled)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_supported) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return _Card(
      title: l.settingsBiometric,
      description: l.settingsBiometricDesc,
      trailing: Switch(value: _enabled, onChanged: _toggle),
    );
  }
}

/// A settings card: title (+ optional description) and either a [trailing]
/// control on the same row or a [child] block below.
class _Card extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;
  final Widget? child;
  const _Card({
    required this.title,
    this.description,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Padding(
      padding: context.rInsets(bottom: 12),
      child: AvaPanel(
        padding: context.rInsets(all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              TextStyle(color: t.text, fontSize: context.r(15))),
                      if (description != null) ...[
                        SizedBox(height: context.r(4)),
                        Text(description!,
                            style: TextStyle(
                                color: t.muted, fontSize: context.r(12.5))),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (child != null) ...[
              SizedBox(height: context.r(14)),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
