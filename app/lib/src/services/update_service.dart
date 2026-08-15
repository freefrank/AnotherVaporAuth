import 'package:dio/dio.dart';

import '../core/update_check.dart';
import 'debug_log.dart';

/// Where the version table lives. Overridable at build time so a dev APK can
/// point at a staging table (e.g. a version_dev.json on dl.dotslash.pro with
/// inflated version numbers) and light the banner up on a real device without
/// touching the production endpoint:
///   --dart-define=AVA_VERSION_URL=https://dl.dotslash.pro/version_dev.json
const kUpdateVersionUrl = String.fromEnvironment('AVA_VERSION_URL',
    defaultValue: 'https://api.ava.dotslash.pro/v1/version');

/// Fetches `/v1/version` and turns it into an [UpdateDecision].
///
/// The contract that matters is what this class does when things go wrong:
/// nothing. Timeout, DNS failure, non-200, malformed JSON — every failure
/// path returns [UpdateDecision.none] and at most a debug-log line. The check
/// runs at every launch (docs/plans/2026-08-14-update-checker.md), and a
/// launch-time nicety is never allowed to become a launch-time dialog.
///
/// Short timeouts on purpose: this races nothing and blocks nothing, but a
/// hung socket would still hold the isolate's httpclient resources. Five
/// seconds is generous for a  <1 KB edge-cached GET.
class UpdateService {
  UpdateService({Dio? dio, String? url})
      : _url = url ?? kUpdateVersionUrl,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ));

  final Dio _dio;
  final String _url;

  /// One check. [currentVersion] comes from PackageInfo, [channelKey] from
  /// [updateChannelKey].
  Future<UpdateDecision> check({
    required String currentVersion,
    required String channelKey,
  }) async {
    try {
      // The outer timeout lives HERE, not only in the Dio options: options
      // belong to whichever Dio was injected, and a guarantee that can be
      // lost by constructing the service differently is not a guarantee.
      final resp = await _dio
          .get<Map<String, dynamic>>(_url)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return UpdateDecision.none;
      final channels = resp.data?['channels'];
      final decision = decideUpdate(
        channels: channels is Map<String, dynamic> ? channels : null,
        channelKey: channelKey,
        currentVersion: currentVersion,
      );
      // One line either way: "checked, found X" / "checked, up to date" is
      // exactly what a device-side debug log needs to distinguish "the check
      // failed" from "the banner failed" — silence here cost a real-device
      // debugging session on 2026-08-14.
      dlog('update check: $channelKey $currentVersion '
          'keys=${channels is Map ? channels.keys.join(',') : channels.runtimeType} -> '
          '${decision.available ? 'update ${decision.latest}' : 'up to date'}');
      return decision;
    } catch (e) {
      // Expected offline / captive-portal noise. Logged for the debug log
      // people attach to feedback, invisible otherwise.
      dlog('update check: skipped ($e)');
      return UpdateDecision.none;
    }
  }
}
