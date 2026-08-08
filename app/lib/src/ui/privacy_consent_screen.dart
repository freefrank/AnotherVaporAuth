import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import 'widgets/app_logo.dart';
import 'widgets/motion.dart';
import 'widgets/scanline_overlay.dart';

const _privacyUrlEn =
    'https://github.com/freefrank/AnotherVaporAuth/blob/main/PRIVACY.md';
const _privacyUrlZh =
    'https://github.com/freefrank/AnotherVaporAuth/blob/main/PRIVACY_ZH.md';

/// Consent gate: the current Privacy Policy notice must be accepted before the
/// app is usable, and before it touches the network.
///
/// Two modes, because the audience is different. On first run this is an
/// introduction. For someone who already accepted an *earlier* notice it is a
/// correction, and dropping them back onto a welcome screen they last saw
/// months ago reads as though their install was reset — so that case leads
/// with what changed, then shows the same current text.
///
/// Accepting requires scrolling to the end first. The point is not to make
/// anyone read — nothing can do that — but to remove "I never saw that" as a
/// fair complaint about a notice that names the services AVA contacts.
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  final _scroll = ScrollController();

  /// Whether the notice has been read to the end — or never needed scrolling.
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_check);
    // Content that fits the viewport has no scroll extent to consume, so the
    // gate has to open on its own. Getting this wrong leaves the button dead
    // forever on a tablet or a desktop window — the classic failure of this
    // pattern. Checked after the first layout, when the extent is known.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _check() {
    if (_reachedEnd || !_scroll.hasClients || !mounted) return;
    final pos = _scroll.position;
    // A few pixels of slack: fractional layout means `pixels` can settle just
    // short of `maxScrollExtent` even when the user is visibly at the bottom.
    if (pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 8) {
      setState(() => _reachedEnd = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final isUpdate =
        ref.watch(appControllerProvider).value?.privacyNeedsUpdate ?? false;
    return Scaffold(
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // Re-checks when the metrics change without a scroll — resizing a
            // desktop window, or rotating a phone, can turn a scrollable
            // notice into one that fits.
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _check();
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                padding: context.rSafeInsets(all: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingLogo(child: AppLogo(size: context.r(84))),
                    SizedBox(height: context.r(20)),
                    Text(
                      isUpdate ? l.privacyUpdateTitle : l.privacyConsentTitle,
                      style: TextStyle(
                          fontSize: context.r(22), fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: context.r(14)),
                    if (isUpdate) ...[
                      Text(l.privacyUpdateBody, textAlign: TextAlign.center),
                      SizedBox(height: context.r(12)),
                      const Divider(),
                      SizedBox(height: context.r(12)),
                    ],
                    Text(l.privacyConsentBody, textAlign: TextAlign.center),
                    SizedBox(height: context.r(12)),
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(isZh ? _privacyUrlZh : _privacyUrlEn),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l.privacyConsentRead),
                    ),
                    SizedBox(height: context.r(16)),
                    // A disabled button with no stated reason reads as a bug,
                    // so say why while it is disabled.
                    if (!_reachedEnd) ...[
                      Text(
                        l.privacyConsentScrollHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.r(12),
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      SizedBox(height: context.r(8)),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _reachedEnd
                            ? () => ref
                                .read(appControllerProvider.notifier)
                                .acceptPrivacy()
                            : null,
                        child: Text(l.privacyConsentAgree),
                      ),
                    ),
                    SizedBox(height: context.r(8)),
                    TextButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: Text(l.privacyConsentExit),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
