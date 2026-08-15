import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/channel.dart';

const _kPlayUrl =
    'https://play.google.com/store/apps/details?id=pro.dotslash.ava';
const _kDownloadUrl = 'https://ava.dotslash.pro/#download';

/// One slim line above the home screen when a newer version is known.
///
/// v1.3 is inform-only (docs/plans/2026-08-14-update-checker.md): the action
/// opens the store page (play) or the download page (everything else), never
/// downloads anything itself. Renders nothing at all in the common case —
/// the provider stays at `none` unless a check found a newer, un-dismissed
/// version, so this widget costs an empty build almost always.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decision = ref.watch(updateDecisionProvider);
    final latest = decision.latest;
    if (!decision.available || latest == null) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Material(
      color: t.panel,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.system_update_alt, size: 18, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.updateAvailable(latest),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                // "Not this version" — persisted; the next version asks again.
                onPressed: () =>
                    ref.read(updateDecisionProvider.notifier).dismiss(),
                child: Text(l.updateDismiss),
              ),
              FilledButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                      avaChannel == AvaChannel.play ? _kPlayUrl : _kDownloadUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(l.updateView),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
