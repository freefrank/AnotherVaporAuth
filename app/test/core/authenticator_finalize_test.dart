import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/authenticator_linker.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake client that replays queued FinalizeAddAuthenticator responses and
/// records the `authenticator_time` (field 3) of each submitted request.
class _FakeApi extends SteamApiClient {
  final List<ProtoReader> responses;
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
    return responses.removeAt(0);
  }
}

ProtoReader _resp({bool success = false, bool wantMore = false, int status = 0}) {
  final w = ProtoWriter()
    ..writeBool(1, success)
    ..writeBool(2, wantMore)
    ..writeVarint(4, status);
  return ProtoReader(w.toBytes());
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
      _resp(wantMore: true),
      _resp(status: 88),
      _resp(success: true),
    ]);
    var clock = 1000; // arbitrary start
    final linker = AuthenticatorLinker(
      api,
      SessionData(steamId: 123, accessToken: 't'),
      now: () => clock,
      sleep: (d) async => clock += d.inSeconds, // fake time passes
    )..linkedAccount = SteamGuardAccount(
        sharedSecret: 'YQ==', // base64("a") — any valid secret
      );

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
}
