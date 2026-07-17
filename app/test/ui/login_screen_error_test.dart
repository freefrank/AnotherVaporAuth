import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays one queued protobuf response for any call.
class _FakeApi extends SteamApiClient {
  final List<ProtoReader> responses;
  _FakeApi(this.responses);

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    return responses.removeAt(0);
  }
}

/// Keeps the skin spec null (plain look) so ScanlineOverlay renders no
/// looping animation — otherwise pumpAndSettle would never settle.
class _NoSkinSpec extends SkinSpecController {
  @override
  build() => null;
}

Future<void> _pumpLogin(WidgetTester tester, _FakeApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        skinSpecProvider.overrideWith(_NoSkinSpec.new),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.neon),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const LoginScreen(reason: LoginReason.add),
      ),
    ),
  );
  // Bounded pumps throughout: the login screen's Stepper3 pulses forever, so
  // pumpAndSettle never settles here.
  await tester.pump();
}

void main() {
  testWidgets(
      'a malformed Steam payload shows the network copy, not a parser dump',
      (tester) async {
    // GetPasswordRSAPublicKey answered with a truncated buffer (a varint cut
    // mid-continuation) — parse() throws ProtoParseException in the screen's
    // generic catch, which used to render the raw '$e' string.
    final api = _FakeApi([
      ProtoReader(Uint8List.fromList([0x0A, 0x05, 0x61])),
    ]);
    await _pumpLogin(tester, api);

    await tester.tap(find.text('Log in'));
    await tester.pump(); // _startPassword awaits the (already-failed) call
    await tester.pump(const Duration(milliseconds: 100)); // error lands

    expect(find.text('Network error — try again later.'), findsOneWidget);
    expect(find.textContaining('protobuf'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('RangeError'), findsNothing);
  });
}
