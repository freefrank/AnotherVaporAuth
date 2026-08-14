import 'package:dio/dio.dart';

import '../core/update_check.dart';
import 'debug_log.dart';

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
  UpdateService({Dio? dio, String base = 'https://api.ava.dotslash.pro'})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: base,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ));

  final Dio _dio;

  /// One check. [currentVersion] comes from PackageInfo, [channelKey] from
  /// [updateChannelKey], [dismissedVersion] from settings.
  Future<UpdateDecision> check({
    required String currentVersion,
    required String channelKey,
    String? dismissedVersion,
  }) async {
    try {
      // The outer timeout lives HERE, not only in the Dio options: options
      // belong to whichever Dio was injected, and a guarantee that can be
      // lost by constructing the service differently is not a guarantee.
      final resp = await _dio
          .get<Map<String, dynamic>>('/v1/version')
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return UpdateDecision.none;
      final channels = resp.data?['channels'];
      return decideUpdate(
        channels: channels is Map<String, dynamic> ? channels : null,
        channelKey: channelKey,
        currentVersion: currentVersion,
        dismissedVersion: dismissedVersion,
      );
    } catch (e) {
      // Expected offline / captive-portal noise. Logged for the debug log
      // people attach to feedback, invisible otherwise.
      dlog('update check: skipped ($e)');
      return UpdateDecision.none;
    }
  }
}
