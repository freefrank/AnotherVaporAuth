import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import 'debug_log_screen.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/sda_panel.dart';

/// Design screen 08 — settings. Each option is a panel card with a title, a
/// short description and its control. Theme + language are selectable chips.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;
    final data = ref.watch(appControllerProvider).value;
    final manifest = data?.store.manifest;
    final variant = ref.watch(themeVariantProvider);
    final locale = ref.watch(localeProvider);

    if (manifest == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    Future<void> save() async {
      await data!.store.save();
      ref.invalidate(appControllerProvider);
    }

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
                    child: Text(l.settingsChange),
                  ),
                ),
                // Biometric / device-credential unlock
                const _BiometricCard(),
                // Periodic checking + auto-confirm
                _Card(
                  title: l.confirmationsTitle,
                  child: Column(
                    children: [
                      _switchRow(context, t, l.settingsPeriodicChecking,
                          manifest.periodicChecking, (v) {
                        manifest.periodicChecking = v;
                        save();
                      }),
                      _switchRow(context, t, l.settingsCheckAll,
                          manifest.checkAllAccounts, (v) {
                        manifest.checkAllAccounts = v;
                        save();
                      }),
                      _switchRow(context, t, l.settingsAutoConfirmMarket,
                          manifest.autoConfirmMarketTransactions, (v) {
                        manifest.autoConfirmMarketTransactions = v;
                        save();
                      }),
                      _switchRow(context, t, l.settingsAutoConfirmTrades,
                          manifest.autoConfirmTrades, (v) {
                        manifest.autoConfirmTrades = v;
                        save();
                      }),
                    ],
                  ),
                ),
                // Theme
                _Card(
                  title: l.settingsTheme,
                  description: l.settingsThemeDesc,
                  child: Wrap(
                    spacing: context.r(8),
                    children: [
                      _choice(context, t, l.themeNeon,
                          variant == SdaThemeVariant.neon,
                          () => ref
                              .read(themeVariantProvider.notifier)
                              .setVariant(SdaThemeVariant.neon)),
                      _choice(context, t, l.themePixel,
                          variant == SdaThemeVariant.pixel,
                          () => ref
                              .read(themeVariantProvider.notifier)
                              .setVariant(SdaThemeVariant.pixel)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchRow(BuildContext context, SdaTokens t, String label,
      bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(color: t.text, fontSize: context.r(14)))),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _choice(BuildContext context, SdaTokens t, String label, bool selected,
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
    final oldKeyCtrl = TextEditingController();
    final newKeyCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsSetPasskey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.encrypted)
              TextField(
                controller: oldKeyCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: l.passkeyLabel),
              ),
            TextField(
              controller: newKeyCtrl,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: '${l.passkeyLabel} (new)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonOk)),
        ],
      ),
    );

    if (ok != true) return;
    final newKey = newKeyCtrl.text.isEmpty ? null : newKeyCtrl.text;
    final oldKey = oldKeyCtrl.text.isEmpty ? null : oldKeyCtrl.text;
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
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Padding(
      padding: context.rInsets(bottom: 12),
      child: SdaPanel(
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
