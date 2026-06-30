import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/theme.dart';
import 'widgets/motion.dart';
import 'widgets/scanline_overlay.dart';
import 'import_helper.dart';
import 'login_screen.dart';

/// Design screen 02 — welcome / first run. Floating logo + two CTA cards:
/// log in to set up a new authenticator, or import an existing .maFile.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<SdaTokens>()!;

    return Scaffold(
      body: ScanlineOverlay(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingLogo(
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.panel2,
                        border: t.border,
                        borderRadius: BorderRadius.circular(t.radius),
                        boxShadow: t.glowShadow(blur: 18),
                      ),
                      child: Text(
                        '2FA',
                        style: TextStyle(
                          color: t.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.text, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.muted, fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  _Cta(
                    title: l.welcomeLoginCta,
                    subtitle: l.welcomeLoginSub,
                    emphasized: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(reason: LoginReason.add))),
                  ),
                  const SizedBox(height: 14),
                  _Cta(
                    title: l.welcomeImportCta,
                    subtitle: l.welcomeImportSub,
                    emphasized: false,
                    onTap: () => importMaFileFlow(context, ref),
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

class _Cta extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool emphasized;
  final VoidCallback onTap;
  const _Cta({
    required this.title,
    required this.subtitle,
    required this.emphasized,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    final bg = emphasized ? t.accent : t.panel;
    final titleColor = emphasized ? const Color(0xFF06060F) : t.text;
    final subColor = emphasized
        ? const Color(0xFF06060F).withValues(alpha: 0.7)
        : t.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(t.radius),
          border: t.border,
          boxShadow: emphasized ? t.glowShadow() : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: titleColor, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: subColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
