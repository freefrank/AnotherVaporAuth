import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/ui/move_in_rescue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system back cannot leave the rescue screen unconfirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAvaTheme(AvaThemeVariant.neon),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const MoveInRescueScreen(
            secrets: (code: 'R99999', secret: 'SECRET'),
          ),
        ),
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(MoveInRescueScreen)),
    );

    // The screen is the root route, so system back would finish the activity
    // and drop the memory-only secrets. Back routes through maybePop —
    // PopScope(canPop: false) must swallow it and open the confirm dialog.
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(MoveInRescueScreen), findsOneWidget);
    expect(find.text(l.moveInRescueDismissTitle), findsOneWidget);

    // Cancel keeps the screen (and the secrets) alive.
    await tester.tap(find.text(l.commonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(MoveInRescueScreen), findsOneWidget);
    expect(find.text(l.moveInRescueDismissTitle), findsNothing);
  });
}
