import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
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
              padding: const EdgeInsets.all(16),
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
                // Periodic checking + auto-confirm
                _Card(
                  title: l.confirmationsTitle,
                  child: Column(
                    children: [
                      _switchRow(t, l.settingsPeriodicChecking,
                          manifest.periodicChecking, (v) {
                        manifest.periodicChecking = v;
                        save();
                      }),
                      _switchRow(t, l.settingsCheckAll,
                          manifest.checkAllAccounts, (v) {
                        manifest.checkAllAccounts = v;
                        save();
                      }),
                      _switchRow(t, l.settingsAutoConfirmMarket,
                          manifest.autoConfirmMarketTransactions, (v) {
                        manifest.autoConfirmMarketTransactions = v;
                        save();
                      }),
                      _switchRow(t, l.settingsAutoConfirmTrades,
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
                    spacing: 8,
                    children: [
                      _choice(t, l.themeNeon, variant == SdaThemeVariant.neon,
                          () => ref
                              .read(themeVariantProvider.notifier)
                              .setVariant(SdaThemeVariant.neon)),
                      _choice(t, l.themePixel, variant == SdaThemeVariant.pixel,
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
                    spacing: 8,
                    children: [
                      _choice(t, l.settingsLanguageSystem, locale == null,
                          () => ref
                              .read(localeProvider.notifier)
                              .setLocale(null)),
                      _choice(t, 'English', locale?.languageCode == 'en',
                          () => ref
                              .read(localeProvider.notifier)
                              .setLocale(const Locale('en'))),
                      _choice(t, '简体中文', locale?.languageCode == 'zh',
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

  Widget _switchRow(
      SdaTokens t, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: t.text, fontSize: 14))),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _choice(SdaTokens t, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.panel2,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: Border.all(
              color: selected ? t.accent : t.borderColor, width: t.borderWidth),
          boxShadow: selected ? t.glowShadow(blur: 10) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF06060F) : t.text,
            fontSize: 13,
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? l.commonOk : l.unlockInvalid)),
      );
    }
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
      padding: const EdgeInsets.only(bottom: 12),
      child: SdaPanel(
        padding: const EdgeInsets.all(16),
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
                          style: TextStyle(color: t.text, fontSize: 15)),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(description!,
                            style: TextStyle(color: t.muted, fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 14),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
