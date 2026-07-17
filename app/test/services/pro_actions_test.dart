import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/play_channel.dart';
import 'package:ava/src/services/pro_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlay implements PlayChannel {
  bool consent = true;
  bool rewardEarned = true;
  String? restoreToken;
  Object? subscribeError;
  Object? signInError;
  final calls = <String>[];

  @override
  bool signInConfigured = true;

  @override
  MethodChannel get channel => throw UnimplementedError();

  @override
  bool get available => true;

  @override
  Future<bool> ensureConsent() async => consent;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<String> signInIdToken() async {
    calls.add('signin');
    if (signInError != null) throw signInError!;
    return 'id-token-1';
  }

  @override
  Future<String> subscribe() async {
    calls.add('subscribe');
    if (subscribeError != null) throw subscribeError!;
    return 'purchase-token-1';
  }

  @override
  Future<String?> restore() async {
    calls.add('restore');
    return restoreToken;
  }

  @override
  Future<bool> showRewarded(String deviceId) async => rewardEarned;

  @override
  Future<int> bannerHeight(int widthDp) async => 60;
}

class _RecordingApi implements EntitlementApi {
  final calls = <String>[];
  int claimFailures = 0;

  @override
  Future<String> refresh(String token, String deviceId) async => 'jwt';

  @override
  Future<String> verifyPlay(
      {required String idToken,
      required String purchaseToken,
      required String deviceId,
      required String deviceClass}) async {
    calls.add('verifyPlay:$idToken:$purchaseToken:$deviceId:$deviceClass');
    return 'jwt';
  }

  @override
  Future<String> redeemAfdian(
      {required String orderNo,
      required String deviceId,
      required String deviceClass}) async {
    calls.add('redeemAfdian:$orderNo');
    if (orderNo == 'bound') throw EntitlementApiException(403, 'order_bound');
    return 'jwt';
  }

  @override
  Future<String> redeemBeta(
      {required String code,
      required String deviceId,
      required String deviceClass}) async {
    calls.add('redeemBeta:$code');
    if (code == 'capped') {
      throw EntitlementApiException(403, 'code_activation_limit',
          activations: [
            EntitlementActivation(
                deviceClass: 'android',
                activatedAt: DateTime.utc(2026, 7, 16)),
          ]);
    }
    return 'jwt';
  }

  @override
  Future<String> claimVip(
      {required String deviceId, required String deviceClass}) async {
    calls.add('claimVip');
    if (claimFailures-- > 0) throw EntitlementApiException(404, 'no_vip');
    return 'jwt';
  }

  @override
  Future<EntitlementStatus> status(String token) =>
      throw UnimplementedError('status not exercised by ProActions');
}

void main() {
  late _FakePlay play;
  late _RecordingApi api;
  late List<String> adopted;
  late ProActions actions;

  setUp(() {
    play = _FakePlay();
    api = _RecordingApi();
    adopted = [];
    actions = ProActions(
      api: api,
      play: play,
      deviceId: () async => 'dev-1',
      adopt: (raw) async {
        adopted.add(raw);
        return raw == 'jwt';
      },
      deviceClass: 'android',
      vipClaimDelay: Duration.zero,
      vipClaimAttempts: 3,
    );
  });

  test('subscribeViaPlay: sign-in → billing → worker → adopt', () async {
    final r = await actions.subscribeViaPlay();
    expect(r.ok, isTrue);
    // Sign-in MUST precede billing: the money step comes after the fallible
    // no-side-effect step.
    expect(play.calls, ['signin', 'subscribe']);
    expect(api.calls,
        ['verifyPlay:id-token-1:purchase-token-1:dev-1:android']);
    expect(adopted, ['jwt']);
  });

  test('subscribeViaPlay: sign-in failure never reaches billing', () async {
    play.signInError = PlatformException(code: 'not_configured');
    final r = await actions.subscribeViaPlay();
    expect(r.ok, isFalse);
    expect(r.code, 'not_configured');
    // The money assertion: no charge may happen once sign-in has failed.
    expect(play.calls, isNot(contains('subscribe')));
    expect(api.calls, isEmpty);
    expect(adopted, isEmpty);
  });

  test('unconfigured sign-in short-circuits both flows before any native call',
      () async {
    play.signInConfigured = false;
    expect((await actions.subscribeViaPlay()).code, 'not_configured');
    expect((await actions.restoreViaPlay()).code, 'not_configured');
    // Neither billing nor restore's native acknowledge may run.
    expect(play.calls, isEmpty);
  });

  test('subscribeViaPlay: user cancel maps to canceled', () async {
    play.subscribeError = PlatformException(code: 'canceled');
    final r = await actions.subscribeViaPlay();
    expect(r.ok, isFalse);
    expect(r.code, 'canceled');
    expect(adopted, isEmpty);
  });

  test('restoreViaPlay: nothing to restore', () async {
    final r = await actions.restoreViaPlay();
    expect(r.code, 'no_subscription');
  });

  test('restoreViaPlay: found token verifies like a purchase', () async {
    play.restoreToken = 'restored-token';
    final r = await actions.restoreViaPlay();
    expect(r.ok, isTrue);
    expect(api.calls,
        ['verifyPlay:id-token-1:restored-token:dev-1:android']);
  });

  test('redeemAfdian: trims input and surfaces worker error codes', () async {
    expect((await actions.redeemAfdian('  A123  ')).ok, isTrue);
    expect(api.calls.first, 'redeemAfdian:A123');
    expect((await actions.redeemAfdian('bound')).code, 'order_bound');
  });

  test('watchRewarded: polls claimVip until the SSV lands', () async {
    api.claimFailures = 2;
    final r = await actions.watchRewarded();
    expect(r.ok, isTrue);
    expect(api.calls.where((c) => c == 'claimVip').length, 3);
  });

  test('watchRewarded: gives up after the attempt budget', () async {
    api.claimFailures = 99;
    final r = await actions.watchRewarded();
    expect(r.code, 'no_vip');
    expect(api.calls.where((c) => c == 'claimVip').length, 3);
  });

  test('watchRewarded: consent denied blocks the ad', () async {
    play.consent = false;
    final r = await actions.watchRewarded();
    expect(r.code, 'consent');
    expect(api.calls, isEmpty);
  });

  test('redeemBeta: worker refusals pass through verbatim '
      '(code_activation_limit)', () async {
    final r = await actions.redeemBeta('capped');
    expect(r.ok, isFalse);
    expect(r.code, 'code_activation_limit');
    expect(adopted, isEmpty);
  });

  test('adopt failure surfaces bad_token', () async {
    actions = ProActions(
      api: api,
      play: play,
      deviceId: () async => 'dev-1',
      adopt: (_) async => false,
      deviceClass: 'android',
    );
    expect((await actions.redeemBeta('code')).code, 'bad_token');
  });
}
