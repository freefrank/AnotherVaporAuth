import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/add_authenticator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _steamId = 76561198000000123;

/// Method-keyed scripted protobuf fake. A handler may return a
/// [ProtoReader], a [SteamApiException] (thrown), or a Future of either —
/// letting a test gate a response on a Completer it controls.
class _FakeApi extends SteamApiClient {
  final Map<String, Future<Object> Function()> handlers = {};

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    final h = handlers[method];
    if (h == null) throw StateError('unscripted protobuf call: $method');
    final r = await h();
    if (r is SteamApiException) throw r;
    return r as ProtoReader;
  }
}

/// Keeps the skin spec null (plain look) so ScanlineOverlay renders no
/// looping animation — otherwise pumpAndSettle would never settle.
class _NoSkinSpec extends SkinSpecController {
  @override
  build() => null;
}

/// Storage whose account-payload writes fail, driving the movedIn
/// save-failure path (manifest writes still succeed so bootstrap works).
class _MaFileWriteFailingStorage extends MemoryStorageProvider {
  @override
  Future<void> writeFile(String filename, String contents) async {
    if (filename.endsWith('.maFile')) throw Exception('disk full');
    return super.writeFile(filename, contents);
  }
}

/// A `CTwoFactor_AddAuthenticator_Response` — the message Steam nests in
/// `replacement_token` (photocopied from authenticator_move_in_test.dart).
ProtoWriter _addResponse({
  List<int> sharedSecret = const [1, 2, 3],
  String revocationCode = 'R54321',
  int status = 1,
}) => ProtoWriter()
  ..writeBytes(1, sharedSecret)
  ..writeString(3, revocationCode)
  ..writeString(4, 'otpauth://totp/Steam')
  ..writeVarint(5, 1700000000)
  ..writeString(6, 'tester')
  ..writeString(7, 'gid-9')
  ..writeBytes(8, const [4, 5, 6]) // identity_secret
  ..writeBytes(9, const [7, 8, 9]) // secret_1
  ..writeVarint(10, status);

ProtoReader _continueResponse({
  bool? success = true,
  ProtoWriter? replacement,
}) {
  final w = ProtoWriter();
  if (success != null) w.writeBool(1, success);
  if (replacement != null) w.writeMessage(2, replacement);
  return ProtoReader(w.toBytes());
}

/// Scripts the fake up to the challengeCode step: AddAuthenticator says an
/// authenticator is present (eresult 29), ChallengeStart succeeds with the
/// 0-byte body Steam really sends.
void _scriptToChallenge(_FakeApi api) {
  api.handlers['AddAuthenticator'] = () async =>
      SteamApiException(29, 'present', 'AddAuthenticator');
  api.handlers['RemoveAuthenticatorViaChallengeStart'] = () async =>
      ProtoReader(ProtoWriter().toBytes());
}

/// Boots a pre-warmed container (the settings read is real IO) and pumps a
/// host route the tests push [AddAuthenticatorScreen] onto — a pushed route
/// is what gives the screen its AppBar back button and something to reveal
/// on pop, matching production (login_screen pushes it).
Future<(ProviderContainer, GlobalKey<NavigatorState>)> _pumpHost(
  WidgetTester tester,
  _FakeApi api,
  MemoryStorageProvider storage,
) async {
  storage.files['manifest.json'] = jsonEncode(Manifest().toJson());
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      skinSpecProvider.overrideWith(_NoSkinSpec.new),
      storageProvider.overrideWithValue(storage),
      timeAlignerProvider.overrideWithValue(() async {}),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(appControllerProvider.future));

  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navKey,
        theme: buildAvaTheme(AvaThemeVariant.neon),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  return (container, navKey);
}

/// Pushes the screen and walks it to the challengeCode step with the code
/// typed in, ready for a confirm tap.
Future<void> _openChallengeStep(
  WidgetTester tester,
  GlobalKey<NavigatorState> navKey,
) async {
  unawaited(
    navKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => AddAuthenticatorScreen(
          session: SessionData(steamId: _steamId, accessToken: 't'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    find.text('This account already has an authenticator'),
    findsOneWidget,
  );

  await tester.tap(find.text('Move the authenticator to this device'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'ABCDE');
}

void main() {
  testWidgets(
    'a malformed Steam payload shows the generic failure, not a parser dump',
    (tester) async {
      final api = _FakeApi();
      // AddAuthenticator answered with a truncated buffer (wire-2 length
      // overrunning the payload) — parse() throws ProtoParseException in the
      // screen's generic catch, which used to render the raw '$e' string.
      api.handlers['AddAuthenticator'] = () async =>
          ProtoReader(Uint8List.fromList([0x0A, 0x05, 0x61]));
      final (_, navKey) = await _pumpHost(tester, api, MemoryStorageProvider());
      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => AddAuthenticatorScreen(
              session: SessionData(steamId: _steamId, accessToken: 't'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to add authenticator'), findsOneWidget);
      expect(find.textContaining('protobuf'), findsNothing);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(find.textContaining('RangeError'), findsNothing);
    },
  );

  testWidgets('back is blocked while a move-in submit is in flight', (
    tester,
  ) async {
    final api = _FakeApi();
    _scriptToChallenge(api);
    final gate = Completer<Object>();
    api.handlers['RemoveAuthenticatorViaChallengeContinue'] = () => gate.future;
    final (_, navKey) = await _pumpHost(tester, api, MemoryStorageProvider());
    await _openChallengeStep(tester, navKey);

    await tester.tap(find.text('Move it here'));
    await tester.pump(); // _lockPop = true, Continue pending

    // Both the AppBar back button and system back route through maybePop —
    // PopScope(canPop: !_lockPop) must swallow it and say why.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byType(AddAuthenticatorScreen),
      findsOneWidget,
      reason: 'popping mid-continue would orphan the swapped token',
    );
    expect(
      find.text('Moving the authenticator — please wait.'),
      findsOneWidget,
    );
    // Let the blocked-pop snackbar's dismiss timer expire.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Resolve cleanly (no replacement token = bad code, nothing swapped).
    gate.complete(_continueResponse(replacement: null));
    await tester.pumpAndSettle();
    expect(find.byType(AddAuthenticatorScreen), findsOneWidget);

    // Idle again: back pops normally.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AddAuthenticatorScreen), findsNothing);
  });

  testWidgets('back stays available while the initial add request is busy', (
    tester,
  ) async {
    final api = _FakeApi();
    final gate = Completer<Object>();
    api.handlers['AddAuthenticator'] = () => gate.future;
    final (_, navKey) = await _pumpHost(tester, api, MemoryStorageProvider());
    unawaited(
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => AddAuthenticatorScreen(
            session: SessionData(steamId: _steamId, accessToken: 't'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(); // post-frame _add fired; request pending
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Only the move-in continue window is irreversible — a busy initial add
    // persists nothing, so back must NOT be swallowed here.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byType(AddAuthenticatorScreen),
      findsNothing,
      reason: 'blocking back outside the move-in window traps the user',
    );

    // Resolve the orphaned request; the disposed State must swallow it.
    gate.complete(SteamApiException(29, 'present', 'AddAuthenticator'));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed save during the add step does NOT arm the root rescue', (
    tester,
  ) async {
    final api = _FakeApi();
    api.handlers['AddAuthenticator'] = () async =>
        ProtoReader(_addResponse().toBytes());
    final (container, navKey) = await _pumpHost(
      tester,
      api,
      _MaFileWriteFailingStorage(),
    );
    unawaited(
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => AddAuthenticatorScreen(
            session: SessionData(steamId: _steamId, accessToken: 't'),
          ),
        ),
      ),
    );
    // Same real-zone interleave as the move-in save-failure test: the store's
    // write-lock future only completes on real event-loop turns.
    for (
      var i = 0;
      i < 10 && find.textContaining('R54321').evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    // Inline error with the revocation code shows on the screen…
    expect(find.textContaining('R54321'), findsOneWidget);
    // …but the rescue takeover must NOT arm: finalize was skipped, nothing is
    // attached on Steam's side, and the rescue screen's "old authenticator is
    // dead" emergency copy would be false for this fully-recoverable state.
    expect(
      container.read(moveInRescueProvider),
      isNull,
      reason: 'pre-finalize save failure is recoverable — no rescue takeover',
    );
  });

  testWidgets('a move-in that outlives the screen still persists the secrets', (
    tester,
  ) async {
    final api = _FakeApi();
    _scriptToChallenge(api);
    final gate = Completer<Object>();
    api.handlers['RemoveAuthenticatorViaChallengeContinue'] = () => gate.future;
    final storage = MemoryStorageProvider();
    final (_, navKey) = await _pumpHost(tester, api, storage);
    await _openChallengeStep(tester, navKey);

    await tester.tap(find.text('Move it here'));
    await tester.pump(); // Continue pending

    // Kill the route out from under the in-flight submit (pushReplacement
    // does not consult PopScope — this is the unmount race itself).
    navKey.currentState!.pushReplacement(
      MaterialPageRoute(builder: (_) => const Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AddAuthenticatorScreen), findsNothing);

    gate.complete(_continueResponse(replacement: _addResponse()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // The only copy of the new shared_secret ([1,2,3] → 'AQID') reached disk
    // even though the State was disposed mid-await.
    final maFile = storage.files['$_steamId.maFile'];
    expect(
      maFile,
      isNotNull,
      reason: 'unmount during moveInContinue must not drop the save',
    );
    expect(maFile, contains('AQID'));
    expect(maFile, contains('R54321'));
  });

  testWidgets('a failed save surfaces the secrets and arms the root rescue', (
    tester,
  ) async {
    final api = _FakeApi();
    _scriptToChallenge(api);
    api.handlers['RemoveAuthenticatorViaChallengeContinue'] = () async =>
        _continueResponse(replacement: _addResponse());
    final (container, navKey) = await _pumpHost(
      tester,
      api,
      _MaFileWriteFailingStorage(),
    );
    await _openChallengeStep(tester, navKey);

    await tester.tap(find.text('Move it here'));
    // The store's write-lock future was created in the runAsync (real) zone —
    // its completion only propagates on real event-loop turns, so interleave
    // real waits with pumps until the save failure lands.
    for (
      var i = 0;
      i < 10 && container.read(moveInRescueProvider) == null;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    // Inline fatal UI on the still-mounted screen…
    expect(find.textContaining('Revocation code: R54321'), findsOneWidget);
    // …and the root-level fallback armed regardless of mount state.
    final rescue = container.read(moveInRescueProvider);
    expect(rescue, isNotNull);
    expect(rescue!.code, 'R54321');
    expect(rescue.secret, base64.encode(const [1, 2, 3]));
  });
}
