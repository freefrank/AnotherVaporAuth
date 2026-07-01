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

/// First-run gate: the user must accept the Privacy Policy before using the app.
class PrivacyConsentScreen extends ConsumerWidget {
  const PrivacyConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: context.rInsets(all: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingLogo(child: AppLogo(size: context.r(84))),
                  SizedBox(height: context.r(20)),
                  Text(
                    l.privacyConsentTitle,
                    style: TextStyle(
                        fontSize: context.r(22), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: context.r(14)),
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          ref.read(appControllerProvider.notifier).acceptPrivacy(),
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
    );
  }
}
