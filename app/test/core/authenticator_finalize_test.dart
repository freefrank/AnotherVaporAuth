import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/authenticator_linker.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake client that replays queued FinalizeAddAuthenticator responses
/// (a [ProtoReader], or a [SteamApiException] to throw) and records the
/// `authenticator_time` (field 3) of each submitted request.
class _FakeApi extends SteamApiClient {
  final List<Object> responses;
  final List<int> submittedTimes = [];
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
    final f = ProtoReader(request.toBytes()).parse();
    submittedTimes.add(f[3]?.asInt ?? 0);
    final r = responses.removeAt(0);
    if (r is SteamApiException) throw r;
    return r as ProtoReader;
  }
}

/// Null params stay absent from the wire — `success: false` writes an
/// explicit varint 0, which the linker must treat differently from a
/// missing optional field.
ProtoReader _resp({bool? success, bool? wantMore, int? status}) {
  final w = ProtoWriter();
  if (success != null) w.writeBool(1, success);
  if (wantMore != null) w.writeBool(2, wantMore);
  if (status != null) w.writeVarint(4, status);
  return ProtoReader(w.toBytes());
}

AuthenticatorLinker _linker(_FakeApi api) {
  var clock = 1000; // arbitrary start
  return AuthenticatorLinker(
    api,
    SessionData(steamId: 123, accessToken: 't'),
    now: () => clock,
    sleep: (d) async => clock += d.inSeconds, // fake time passes
  )..linkedAccount = SteamGuardAccount(
      sharedSecret: 'YQ==', // base64("a") — any valid secret
    );
}

void main() {
  test('windowWaitSeconds waits out the current window, 0 once past it', () {
    // Same 30s window (0..29): must wait to just past the boundary.
    expect(AuthenticatorLinker.windowWaitSeconds(10, 10), 21); // 30-10+1
    expect(AuthenticatorLinker.windowWaitSeconds(0, 29), 2); // 30-29+1
    // Already in a later window: no wait.
    expect(AuthenticatorLinker.windowWaitSeconds(10, 30), 0);
    expect(AuthenticatorLinker.windowWaitSeconds(10, 90), 0);
  });

  test('finalize submits each code from a fresh TOTP window', () async {
    final api = _FakeApi([
      _resp(success: false, wantMore: true),
      _resp(success: false, status: 88),
      _resp(success: true),
    ]);
    final linker = _linker(api);

    final result = await linker.finalize('ACTIVATE');

    expect(result, FinalizeResult.success);
    expect(api.submittedTimes.length, 3);
    // Each submission must land in a strictly later 30-second window than the
    // previous one — i.e. no code was ever resubmitted in the same window.
    final windows = api.submittedTimes.map((t) => t ~/ 30).toList();
    for (var i = 1; i < windows.length; i++) {
      expect(windows[i], greaterThan(windows[i - 1]), reason: '$windows');
    }
  });

  group('finalize success signal — eresult + explicit evidence only', () {
    test('eresult OK with a 0-byte body is success, not failure', () async {
      // The measured success shape of the sibling Remove* endpoints: OK
      // header, `success` never filled. Defaulting the missing optional to
      // false would tell the user the link failed while Steam Guard is live.
      final api = _FakeApi([ProtoReader(Uint8List(0))]);
      final linker = _linker(api);

      expect(await linker.finalize('ACTIVATE'), FinalizeResult.success);
      expect(linker.linkedAccount!.fullyEnrolled, isTrue);
    });

    test('explicit success=true is success', () async {
      final linker = _linker(_FakeApi([_resp(success: true)]));
      expect(await linker.finalize('ACTIVATE'), FinalizeResult.success);
      expect(linker.linkedAccount!.fullyEnrolled, isTrue);
    });

    test('success=false + want_more retries in the next window, then succeeds',
        () async {
      final api = _FakeApi([
        _resp(success: false, wantMore: true),
        _resp(success: true),
      ]);
      final linker = _linker(api);

      expect(await linker.finalize('ACTIVATE'), FinalizeResult.success);
      expect(api.submittedTimes.length, 2);
      expect(api.submittedTimes[1] ~/ 30,
          greaterThan(api.submittedTimes[0] ~/ 30));
    });

    test('status 89 is badSmsCode', () async {
      final linker = _linker(_FakeApi([_resp(status: 89)]));
      expect(await linker.finalize('ACTIVATE'), FinalizeResult.badSmsCode);
      expect(linker.linkedAccount!.fullyEnrolled, isFalse);
    });

    test('status 88 alone retries — never success in that window', () async {
      final api = _FakeApi([
        _resp(status: 88),
        _resp(success: true),
      ]);
      final linker = _linker(api);

      expect(await linker.finalize('ACTIVATE'), FinalizeResult.success);
      expect(api.submittedTimes.length, 2);
    });

    test('explicit success=false with nothing else is generalFailure',
        () async {
      final linker =
          _linker(_FakeApi([_resp(success: false, wantMore: false, status: 0)]));
      expect(await linker.finalize('ACTIVATE'), FinalizeResult.generalFailure);
      expect(linker.linkedAccount!.fullyEnrolled, isFalse);
    });

    test('a non-OK eresult propagates as SteamApiException', () async {
      final linker = _linker(
          _FakeApi([SteamApiException(2, 'Fail', 'FinalizeAddAuthenticator')]));
      await expectLater(
        linker.finalize('ACTIVATE'),
        throwsA(isA<SteamApiException>()),
      );
      expect(linker.linkedAccount!.fullyEnrolled, isFalse);
    });
  });
}
