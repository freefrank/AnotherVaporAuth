import '../../services/steam_api_client.dart';
import '../../services/steam_time.dart';
import '../models/confirmation.dart';
import '../models/steam_guard_account.dart';
import '../steam_totp.dart';

/// Fetches and acts on Steam mobile confirmations (`steamcommunity.com/mobileconf`).
///
/// Pure JSON protocol (no WebView): `getlist` returns the confirmation array,
/// `ajaxop` / `multiajaxop` accept or reject. All requests are signed with the
/// account's `identity_secret` per the time + tag scheme.
class ConfirmationsClient {
  final SteamApiClient api;
  ConfirmationsClient(this.api);

  /// Result of a batch operation.
  /// [ok] confirmations succeeded, [failed] did not.
  Future<List<Confirmation>> fetch(SteamGuardAccount account) async {
    final time = SteamTime.currentSteamTime;
    final query = _baseQuery(account, time, 'list')
      ..['tag'] = 'list'
      // Localizes headline/summary/type_name; not part of the signed hash.
      ..['l'] = api.steamLanguage;
    final json = await api.communityGetJson(
      '/mobileconf/getlist',
      query,
      cookies: _cookies(account),
    );
    if (json['success'] != true) {
      if (json['needauth'] == true || json['needsauth'] == true) {
        throw const ConfirmationAuthException();
      }
      // A signature-level rejection ("哦，不！" / "Oh no!") — the
      // identity_secret/device_id doesn't match the account's registered
      // authenticator, or the clock is far off. Returning [] here would
      // render a hard rejection as "no pending confirmations".
      throw ConfirmationRejectedException(
          (json['message'] ?? json['detail'] ?? '').toString());
    }
    final list = (json['conf'] as List?) ?? const [];
    return list
        .map((e) => Confirmation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Accepts or rejects a single confirmation. [accept] true = allow.
  Future<bool> respond(
      SteamGuardAccount account, Confirmation conf, bool accept) async {
    final time = SteamTime.currentSteamTime;
    // Steam signs accept/deny with tag == op ('allow' / 'cancel'), not
    // 'accept' / 'reject'.
    final op = accept ? 'allow' : 'cancel';
    final tag = op;
    final query = _baseQuery(account, time, tag)
      ..['tag'] = tag
      ..['op'] = op
      ..['cid'] = conf.id
      ..['ck'] = conf.nonce;
    final json = await api.communityPostJson(
      '/mobileconf/ajaxop',
      query,
      cookies: _cookies(account),
    );
    return json['success'] == true;
  }

  /// Batch accept/reject. Tries `multiajaxop`; on failure falls back to
  /// per-item [respond] and reports aggregate success/failure.
  Future<BatchResult> respondMultiple(
    SteamGuardAccount account,
    List<Confirmation> confs,
    bool accept,
  ) async {
    if (confs.isEmpty) return const BatchResult(0, 0);
    final time = SteamTime.currentSteamTime;
    // Steam signs accept/deny with tag == op ('allow' / 'cancel').
    final op = accept ? 'allow' : 'cancel';
    final tag = op;
    final query = _baseQuery(account, time, tag)
      ..['tag'] = tag
      ..['op'] = op;
    // multiajaxop expects repeated cid[]/ck[].
    final cids = confs.map((c) => c.id).toList();
    final cks = confs.map((c) => c.nonce).toList();
    query['cid[]'] = cids;
    query['ck[]'] = cks;

    try {
      final json = await api.communityPostJson(
        '/mobileconf/multiajaxop',
        query,
        cookies: _cookies(account),
      );
      if (json['success'] == true) {
        return BatchResult(confs.length, 0);
      }
    } catch (_) {
      // fall through to per-item
    }

    var ok = 0;
    var failed = 0;
    for (final c in confs) {
      try {
        if (await respond(account, c, accept)) {
          ok++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }
    return BatchResult(ok, failed);
  }

  Map<String, dynamic> _baseQuery(
      SteamGuardAccount account, int time, String tag) {
    final hash = SteamTotp.generateConfirmationHash(
        time, tag, account.identitySecret ?? '');
    // An empty device id is always rejected; a maFile that lost its
    // `device_id` field falls back to the deterministic SteamID-derived one.
    final deviceId = account.deviceId;
    return <String, dynamic>{
      'p': (deviceId == null || deviceId.isEmpty)
          ? SteamTotp.generateDeviceId(account.steamId)
          : deviceId,
      'a': '${account.steamId}',
      'k': hash,
      't': '$time',
      'm': 'react',
    };
  }

  Map<String, String> _cookies(SteamGuardAccount account) {
    final token = account.session.accessToken ?? '';
    return {
      'steamLoginSecure': '${account.steamId}||$token',
      'mobileClient': 'android',
      'mobileClientVersion': '777777 3.6.4',
    };
  }
}

class BatchResult {
  final int ok;
  final int failed;
  const BatchResult(this.ok, this.failed);
}

class ConfirmationAuthException implements Exception {
  const ConfirmationAuthException();
  @override
  String toString() => 'ConfirmationAuthException: session needs re-auth';
}

/// Steam answered a mobileconf call with `success=false` but no auth flag:
/// the request reached Steam and was rejected at the signature level
/// (mismatched identity_secret / device_id, or heavy clock drift) — retrying
/// with the same secrets cannot succeed. [message] is Steam's own (localized)
/// error text, when present.
class ConfirmationRejectedException implements Exception {
  final String message;
  const ConfirmationRejectedException(this.message);
  @override
  String toString() => 'ConfirmationRejectedException: $message';
}
