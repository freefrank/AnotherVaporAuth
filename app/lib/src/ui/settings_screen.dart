import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(appControllerProvider).value;
    final manifest = data?.store.manifest;
    final locale = ref.watch(localeProvider);

    if (manifest == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    Future<void> saveManifest() async {
      await data!.store.save();
      ref.invalidate(appControllerProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          _section(context, l.settingsEncryption),
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l.settingsSetPasskey),
            onTap: () => _changePasskey(context, ref),
          ),
          const Divider(),
          _section(context, l.confirmationsTitle),
          SwitchListTile(
            title: Text(l.settingsPeriodicChecking),
            value: manifest.periodicChecking,
            onChanged: (v) {
              manifest.periodicChecking = v;
              saveManifest();
            },
          ),
          ListTile(
            title: Text(l.settingsCheckInterval),
            trailing: SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: '${manifest.periodicCheckingInterval}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                onFieldSubmitted: (v) {
                  manifest.periodicCheckingInterval =
                      int.tryParse(v) ?? manifest.periodicCheckingInterval;
                  saveManifest();
                },
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l.settingsCheckAll),
            value: manifest.checkAllAccounts,
            onChanged: (v) {
              manifest.checkAllAccounts = v;
              saveManifest();
            },
          ),
          SwitchListTile(
            title: Text(l.settingsAutoConfirmMarket),
            value: manifest.autoConfirmMarketTransactions,
            onChanged: (v) {
              manifest.autoConfirmMarketTransactions = v;
              saveManifest();
            },
          ),
          SwitchListTile(
            title: Text(l.settingsAutoConfirmTrades),
            value: manifest.autoConfirmTrades,
            onChanged: (v) {
              manifest.autoConfirmTrades = v;
              saveManifest();
            },
          ),
          const Divider(),
          _section(context, l.settingsTheme),
          RadioGroup<SdaThemeVariant>(
            groupValue: ref.watch(themeVariantProvider),
            onChanged: (v) {
              if (v != null) {
                ref.read(themeVariantProvider.notifier).setVariant(v);
              }
            },
            child: Column(
              children: [
                RadioListTile<SdaThemeVariant>(
                  value: SdaThemeVariant.neon,
                  title: Text(l.themeNeon),
                ),
                RadioListTile<SdaThemeVariant>(
                  value: SdaThemeVariant.pixel,
                  title: Text(l.themePixel),
                ),
              ],
            ),
          ),
          const Divider(),
          _section(context, l.settingsLanguage),
          RadioGroup<String?>(
            groupValue: locale?.languageCode,
            onChanged: (v) => ref
                .read(localeProvider.notifier)
                .setLocale(v == null ? null : Locale(v)),
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(l.settingsLanguageSystem),
                ),
                const RadioListTile<String?>(
                  value: 'en',
                  title: Text('English'),
                ),
                const RadioListTile<String?>(
                  value: 'zh',
                  title: Text('简体中文'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );

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
