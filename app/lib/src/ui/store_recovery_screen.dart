import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../services/account_store.dart';

/// Shown by the app root when bootstrap failed with [ManifestParseException]:
/// the account database (manifest.json) is missing or corrupt. Offers retry
/// (transient IO), an evidence-gated manifest rebuild (vault key present but
/// no manifest — payload files are still on disk), and, as a last resort, the
/// same reset-and-reimport escape hatch the unlock screen has.
class StoreRecoveryScreen extends ConsumerStatefulWidget {
  const StoreRecoveryScreen({super.key});

  @override
  ConsumerState<StoreRecoveryScreen> createState() =>
      _StoreRecoveryScreenState();
}

class _StoreRecoveryScreenState extends ConsumerState<StoreRecoveryScreen> {
  bool _busy = false;

  /// True only with hard evidence a rebuild can work: no manifest.json on
  /// disk, but the vault DEK still in the keystore — i.e. the manifest was
  /// lost, not the store. A *corrupt* manifest never offers repair (rebuild
  /// would silently discard whatever the corrupt file still described).
  bool _canRepair = false;

  @override
  void initState() {
    super.initState();
    _checkRepairable();
  }

  Future<void> _checkRepairable() async {
    final storage = ref.read(storageProvider);
    final keyStore = ref.read(vaultKeyStoreProvider);
    final manifestMissing = !await storage.fileExists('manifest.json');
    final hasVaultKey = manifestMissing && await keyStore.exists;
    if (!mounted) return;
    setState(() => _canRepair = manifestMissing && hasVaultKey);
  }

  Future<void> _repair() async {
    setState(() => _busy = true);
    try {
      await AccountStore.rebuildVaultManifest(ref.read(storageProvider));
      // The root swaps automatically once the controller rebuilds.
      ref.invalidate(appControllerProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).storeActionFailed('$e')),
          ),
        );
      }
    } finally {
      // This screen is the recovery path of last resort — a throw above must
      // never leave every button dead behind a stuck _busy.
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.resetVaultTitle),
        content: Text(l.resetVaultBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.bad,
              foregroundColor: const Color(0xFF06060F),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.resetVaultConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // The app root swaps to the (empty, unlocked) home once the state
      // rebuilds — no navigation needed here.
      await ref.read(appControllerProvider.notifier).resetVault();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).storeActionFailed('$e')),
          ),
        );
      }
    } finally {
      // Same rule as _repair: retry/repair/reset stay tappable after a throw.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: context.rInsets(all: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  size: context.r(48),
                  color: t.warn,
                ),
                SizedBox(height: context.r(12)),
                Text(
                  l.storeErrorTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.r(18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.r(10)),
                Text(l.storeErrorBody, textAlign: TextAlign.center),
                SizedBox(height: context.r(20)),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => ref.invalidate(appControllerProvider),
                  child: Text(l.commonRetry),
                ),
                if (_canRepair) ...[
                  SizedBox(height: context.r(12)),
                  OutlinedButton(
                    onPressed: _busy ? null : _repair,
                    child: Text(l.storeRepair),
                  ),
                ],
                SizedBox(height: context.r(18)),
                TextButton(
                  onPressed: _busy ? null : _confirmReset,
                  child: Text(
                    l.resetVaultTitle,
                    style: TextStyle(color: t.muted, fontSize: context.r(12.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
