import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/protocol/community_session.dart'
    show MissingAccessTokenException;
import '../core/protocol/eresult.dart';
import '../core/proto/protobuf_wire.dart';
import 'debug_log.dart';

/// Thin HTTP client for Steam's web APIs.
///
/// Handles the two transports the app needs:
///  - `api.steampowered.com/<Iface>/<Method>/v1` protobuf calls
///    (IAuthenticationService, ITwoFactorService).
///  - `steamcommunity.com/mobileconf/*` confirmation calls (plain query + cookies).
class SteamApiClient {
  static const String apiBase = 'https://api.steampowered.com';
  static const String communityBase = 'https://steamcommunity.com';
  static const String storeBase = 'https://store.steampowered.com';

  /// Whether [url] is a Steam-owned HTTPS origin we may keep sending session
  /// cookies (`steamLoginSecure` etc.) to while following a redirect chain.
  /// A redirect to anything else — a non-HTTPS scheme or a non-Steam host —
  /// must not carry the auth cookies (session-hijack via a rogue redirect).
  static bool isSteamOrigin(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https' || !u.hasAuthority) return false;
    final host = u.host.toLowerCase();
    return host == 'steamcommunity.com' ||
        host == 'steampowered.com' ||
        host == 'store.steampowered.com' ||
        host == 'help.steampowered.com' ||
        host == 'login.steampowered.com' ||
        host == 'api.steampowered.com' ||
        host.endsWith('.steamcommunity.com') ||
        host.endsWith('.steampowered.com');
  }

  final Dio _dio;

  /// Headers that make AVA's requests look like the official Steam mobile app
  /// (it uses an okhttp client + these API headers). Combined with the
  /// MobileApp platform type and device details, this keeps legitimate logins
  /// from tripping Steam's "unknown device" anti-fraud heuristics.
  static const Map<String, String> steamMobileHeaders = {
    'User-Agent': 'okhttp/4.9.2',
    'Accept': 'application/json, text/plain, */*',
    'Sec-Fetch-Site': 'cross-site',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
  };

  /// Steam community language (`l=` query param) for localized strings —
  /// confirmation headlines/summaries, inventory item names. Kept in sync
  /// with the app locale by the UI layer; Steam falls back to English for
  /// values it doesn't recognize.
  String steamLanguage = 'english';

  SteamApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              followRedirects: false,
              validateStatus: (s) => s != null && s < 500,
              headers: Map<String, String>.from(steamMobileHeaders),
            ));

  /// Calls a protobuf service method and returns the decoded response reader.
  ///
  /// [requestProto] is the serialized request message. GET is used for methods
  /// that take no auth/side effects (e.g. GetPasswordRSAPublicKey); everything
  /// else is POST. [accessToken] is appended when the method requires auth.
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    final url = '$apiBase/$iface/$method/v$version/';
    // toBytes() copies the builder's buffer on every call — serialize once.
    final requestBytes = request.toBytes();
    final encoded = base64.encode(requestBytes);
    final query = <String, dynamic>{
      'access_token': ?accessToken,
    };

    dlog('→ ${useGet ? 'GET' : 'POST'} $iface/$method '
        '(${requestBytes.length}B${accessToken != null ? ', +token' : ''})');
    try {
      Response<List<int>> resp;
      if (useGet) {
        resp = await _dio.get<List<int>>(
          url,
          queryParameters: {...query, 'input_protobuf_encoded': encoded},
          options: Options(responseType: ResponseType.bytes),
        );
      } else {
        resp = await _dio.post<List<int>>(
          url,
          queryParameters: query,
          data: FormData.fromMap({'input_protobuf_encoded': encoded}),
          options: Options(responseType: ResponseType.bytes),
        );
      }

      final eresult = int.tryParse(resp.headers.value('x-eresult') ?? '');
      final bytes = resp.data?.length ?? 0;
      dlog('← $method  HTTP ${resp.statusCode}  '
          'eresult=${eresult == null ? 'none' : eresultLabel(eresult)}  ${bytes}B');
      if (eresult != null && eresult != 1) {
        final msg = resp.headers.value('x-error_message');
        dlog('  ✗ $method error: ${msg ?? eresultLabel(eresult)}');
        throw SteamApiException(eresult, msg ?? eresultLabel(eresult), method);
      }
      // No x-eresult header at all: only a plain HTTP success may pass. An
      // expired/invalid access token can come back as a bare 401 with no
      // header — defaulting that to OK would fake a successful call whose
      // empty body then parses as "accepted".
      final status = resp.statusCode ?? 0;
      if (eresult == null && (status < 200 || status >= 300)) {
        dlog('  ✗ $method HTTP $status with no x-eresult');
        throw SteamApiException(2 /* Fail */, 'HTTP $status', method,
            httpStatus: status);
      }
      return ProtoReader(Uint8List.fromList(resp.data ?? const []));
    } on DioException catch (e) {
      dlog('  ✗ $method network: ${e.type.name} ${e.response?.statusCode ?? ''} ${e.message ?? ''}');
      rethrow;
    }
  }

  /// GET against api.steampowered.com returning decoded JSON (non-protobuf
  /// Web API endpoints, e.g. IEconService). [accessToken] is appended as the
  /// `access_token` query param. Returns the decoded top-level object; a
  /// bare 401/403 (expired token) throws [SteamApiException] so callers can
  /// trigger a session refresh, mirroring [callProtobuf]'s contract.
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    final url = '$apiBase/$iface/$method/v$version/';
    dlog('→ GET $iface/$method (json)');
    try {
      final resp = await _dio.get<String>(
        url,
        queryParameters: {'access_token': ?accessToken, ...query},
        options: Options(responseType: ResponseType.plain),
      );
      final status = resp.statusCode ?? 0;
      final body = resp.data ?? '';
      dlog('← $method  HTTP $status  ${body.length}B');
      if (status < 200 || status >= 300) {
        throw SteamApiException(2 /* Fail */, 'HTTP $status', method,
            httpStatus: status);
      }
      final decoded = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on DioException catch (e) {
      dlog('  ✗ $method network: ${e.type.name} ${e.response?.statusCode ?? ''}');
      rethrow;
    }
  }

  /// GET against steamcommunity.com (mobileconf), returning decoded JSON.
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    dlog('→ GET $path  ${query['tag'] ?? ''}${query['op'] != null ? ' op=${query['op']}' : ''}');
    try {
      final resp = await _dio.get<String>(
        '$communityBase$path',
        queryParameters: query,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            if (cookies != null) 'Cookie': _cookieHeader(cookies),
            'X-Requested-With': 'com.valvesoftware.android.steam.community',
          },
        ),
      );
      return _decodeCommunityJson(resp, path);
    } on DioException catch (e) {
      dlog('  ✗ $path network: ${e.type.name} ${e.response?.statusCode ?? ''}');
      rethrow;
    }
  }

  /// Shared response handling for [communityGetJson] / [communityPostJson]:
  /// runs the status gate, then decodes the 2xx body — empty body → `{}`,
  /// and a `success != true` object is logged but still returned (the caller
  /// decides what a soft failure means for its endpoint).
  static Map<String, dynamic> _decodeCommunityJson(
      Response<String> resp, String path) {
    final body = resp.data ?? '';
    dlog('← $path  HTTP ${resp.statusCode}  ${body.length}B');
    final diagnostic = _gateCommunityStatus(resp, path);
    if (diagnostic != null) return diagnostic;
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    // Some write endpoints (e.g. removelisting) reply 200 with a bare `[]` —
    // treat a non-object body as a plain success.
    if (decoded is! Map<String, dynamic>) return const {};
    if (decoded['success'] != true) {
      dlog('  ⚠ $path success=${decoded['success']} '
          '${decoded['message'] ?? decoded['needauth'] ?? ''}');
    }
    return decoded;
  }

  /// Status gate for the community JSON helpers. Returns null for a 2xx (the
  /// caller parses the body as usual); otherwise resolves the response here:
  ///  - 401/403, or a redirect to the login page → the session cookie is
  ///    stale; [CommunityAuthException] so callers route to re-auth instead
  ///    of parsing the (usually empty) body as a success-shaped `{}`.
  ///  - any other redirect (e.g. the market/eligibilitycheck bounce) is not
  ///    an auth failure → [SteamApiException], never a success-shaped `{}`.
  ///  - other non-2xx: Steam reports many command failures as a 4xx carrying
  ///    a JSON diagnostic body (sellitem 400 + `{"message":...}`) — a body
  ///    that decodes to an object is returned so the message reaches the
  ///    caller (which already handles `success != true`); anything else
  ///    → [SteamApiException].
  static Map<String, dynamic>? _gateCommunityStatus(
      Response<String> resp, String path) {
    final status = resp.statusCode ?? 0;
    if (status >= 200 && status < 300) return null;
    if (status == 401 || status == 403) {
      dlog('  ✗ $path HTTP $status (stale session?)');
      throw CommunityAuthException(status, path);
    }
    if (status >= 300 && status < 400) {
      final loc = resp.headers.value('location') ?? '';
      dlog('  ✗ $path HTTP $status → $loc');
      if (_isLoginRedirect(loc)) throw CommunityAuthException(status, path);
      // Carry the target into the message: a bare "HTTP 302" tells the user
      // (and the debug log) nothing, and the store's *self*-redirect — its way
      // of saying "take these cookies and come back" — is indistinguishable
      // from any other bounce without it.
      throw SteamApiException(2 /* Fail */, 'HTTP $status → $loc', path,
          httpStatus: status);
    }
    final body = resp.data ?? '';
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          dlog('  ⚠ $path HTTP $status with diagnostic body');
          return decoded;
        }
      } on FormatException {
        // Not JSON — fall through to the plain HTTP failure.
      }
    }
    dlog('  ✗ $path HTTP $status');
    throw SteamApiException(2 /* Fail */, 'HTTP $status', path,
        httpStatus: status);
  }

  /// Whether a redirect Location targets Steam's login page. Matched on the
  /// URL path only — a `/login` inside a query string (goto=) must not count.
  static bool _isLoginRedirect(String location) {
    if (location.isEmpty) return false;
    final uri = Uri.tryParse(location);
    // steammobile://lostauth is Steam's other stale-mobile-session bounce;
    // its path is empty so the '/login' check alone would miss it.
    if (uri?.scheme == 'steammobile') return true;
    final path = uri?.path ?? location;
    return path.contains('/login');
  }

  /// GETs a community URL and returns the raw response body (HTML/text). Used to
  /// scrape page globals like `g_rgAppContextData` / `g_rgWalletInfo`.
  Future<String> communityGetText(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? cookies,
  }) async {
    // Accumulate cookies across the redirect chain (we have no cookie jar).
    // Steam's inventory page bounces through /market/eligibilitycheck, which
    // Set-Cookies a "passed" flag and redirects back; without carrying that
    // cookie the two pages ping-pong forever.
    final jar = <String, String>{...?cookies};
    Options opts() => Options(
          responseType: ResponseType.plain,
          headers: {
            'Cookie': _cookieHeader(jar),
            'X-Requested-With': 'com.valvesoftware.android.steam.community',
          },
        );
    void absorb(Response resp) {
      for (final sc in resp.headers['set-cookie'] ?? const <String>[]) {
        final kv = sc.split(';').first.trim();
        final i = kv.indexOf('=');
        if (i > 0) jar[kv.substring(0, i)] = kv.substring(i + 1);
      }
    }

    var url = path.startsWith('http') ? path : '$communityBase$path';
    // The initial URL must also clear the origin gate when it's absolute —
    // a relative path resolves under communityBase (always Steam), but an
    // absolute `path` bypasses that and could otherwise ship cookies to a
    // rogue host on the very first request. Defense in depth alongside the
    // redirect-chain check below.
    if (path.startsWith('http') && !isSteamOrigin(url)) {
      throw ArgumentError.value(path, 'path', 'not a Steam origin');
    }
    dlog('→ GET(text) $path');
    var resp = await _dio.get<String>(url, queryParameters: query, options: opts());
    absorb(resp);
    var hops = 0;
    while ((resp.statusCode ?? 0) >= 300 &&
        (resp.statusCode ?? 0) < 400 &&
        hops++ < 6) {
      final loc = resp.headers.value('location');
      if (loc == null || loc.isEmpty) break;
      // Resolve relative redirects against the current URL, then refuse to
      // follow off a Steam origin while carrying session cookies — a rogue
      // redirect to an external host would otherwise leak steamLoginSecure.
      url = Uri.parse(url).resolve(loc).toString();
      // A bounce to the login page means the session cookie is stale — the
      // caller must route to re-auth, not scrape the login page's HTML.
      if (_isLoginRedirect(url)) {
        dlog('  ✗ $path redirected to login (stale session?)');
        throw CommunityAuthException(resp.statusCode ?? 302, path);
      }
      if (!isSteamOrigin(url)) {
        dlog('  ✕ refused off-origin redirect $url');
        break;
      }
      dlog('  ↪ redirect $url');
      resp = await _dio.get<String>(url, options: opts());
      absorb(resp);
    }
    // A bare 401/403 (initial or post-redirect) is a stale session too —
    // the caller would otherwise scrape an error page for its globals.
    final status = resp.statusCode ?? 0;
    if (status == 401 || status == 403) {
      dlog('  ✗ $path HTTP $status (stale session?)');
      throw CommunityAuthException(status, path);
    }
    final body = resp.data ?? '';
    dlog('← $path  HTTP ${resp.statusCode}  ${body.length}B');
    return body;
  }

  /// Like [communityGetJson] but POSTs the params as a form body — the modern
  /// (react) `/mobileconf/ajaxop` and `multiajaxop`, and `/market/*` write
  /// endpoints expect POST. [referer] is required by `/market/sellitem/`.
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    dlog('→ POST $path  ${form['tag'] ?? ''}${form['op'] != null ? ' op=${form['op']}' : ''}');
    try {
      final resp = await _dio.post<String>(
        '$communityBase$path',
        data: form,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          listFormat: ListFormat.multi,
          headers: {
            if (cookies != null) 'Cookie': _cookieHeader(cookies),
            'Referer': ?referer,
            'X-Requested-With': 'com.valvesoftware.android.steam.community',
          },
        ),
      );
      return _decodeCommunityJson(resp, path);
    } on DioException catch (e) {
      dlog('  ✗ $path network: ${e.type.name} ${e.response?.statusCode ?? ''}');
      rethrow;
    }
  }

  /// Warms up a `store.steampowered.com` session and returns the cookie jar to
  /// use for the follow-up request.
  ///
  /// The store answers a request carrying unfamiliar cookies by `Set-Cookie`ing
  /// `steamCountry` + `browserid` and redirecting — **even when
  /// `steamLoginSecure` is perfectly valid**. A browser absorbs those and
  /// retries transparently; we have no cookie jar, so a first POST straight at
  /// an ajax endpoint comes back as a bare 302 to itself and never runs. Doing
  /// this GET first is what makes the POST reach the endpoint.
  ///
  /// Any `sessionid` Steam hands back replaces the caller's generated one: the
  /// store is stricter than the community host, which only cross-checks that
  /// the cookie and the form field agree.
  ///
  /// Redirects are followed only while they stay on a Steam origin (a rogue
  /// redirect would otherwise carry `steamLoginSecure` off-site), and a bounce
  /// to the login page throws [CommunityAuthException] so the caller re-auths
  /// instead of POSTing into a dead session.
  Future<Map<String, String>> storeBootstrap(
    String path,
    Map<String, String> cookies,
  ) async {
    final jar = <String, String>{...cookies};
    void absorb(Response resp) {
      for (final sc in resp.headers['set-cookie'] ?? const <String>[]) {
        final kv = sc.split(';').first.trim();
        final i = kv.indexOf('=');
        if (i > 0) jar[kv.substring(0, i)] = kv.substring(i + 1);
      }
    }

    var url = '$storeBase$path';
    dlog('→ GET(bootstrap) store$path');
    var resp = await _dio.get<String>(url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Cookie': _cookieHeader(jar)},
        ));
    absorb(resp);
    var hops = 0;
    while ((resp.statusCode ?? 0) >= 300 &&
        (resp.statusCode ?? 0) < 400 &&
        hops++ < 4) {
      final loc = resp.headers.value('location');
      if (loc == null || loc.isEmpty) break;
      url = Uri.parse(url).resolve(loc).toString();
      if (_isLoginRedirect(url)) {
        dlog('  ✗ store$path bounced to login (stale session?)');
        throw CommunityAuthException(resp.statusCode ?? 302, 'store$path');
      }
      if (!isSteamOrigin(url)) {
        dlog('  ✕ refused off-origin redirect $url');
        break;
      }
      dlog('  ↪ bootstrap redirect');
      resp = await _dio.get<String>(url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'Cookie': _cookieHeader(jar)},
          ));
      absorb(resp);
    }
    // Cookie *names* only — steamLoginSecure and sessionid are credentials.
    dlog('  store session: ${jar.keys.join(", ")}');
    return jar;
  }

  /// Like [communityPostJson] but against `store.steampowered.com` — the store
  /// hosts its own ajax endpoints (`/account/ajaxregisterkey/`) that the
  /// community host does not serve.
  ///
  /// Status handling is shared with the community helpers on purpose: the
  /// store answers a stale session with a 302 to the login page, which
  /// [_gateCommunityStatus] turns into [CommunityAuthException] so callers
  /// route to re-auth instead of parsing the login HTML as a failed
  /// activation. Note the store reports *endpoint-level* success as
  /// `success: 1` (an int), not `true`, so callers must read the numeric
  /// result themselves rather than trusting the shared `success != true` log.
  ///
  /// `X-Requested-With` is the plain `XMLHttpRequest` a browser sends, NOT the
  /// `com.valvesoftware.android.steam.community` package marker the community
  /// helpers use: these are the store's own page-backing ajax endpoints, and
  /// the community app's marker is what makes Steam serve the stripped
  /// mobile-app layout instead of the JSON we asked for.
  Future<Map<String, dynamic>> storePostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    dlog('→ POST store$path');
    try {
      final resp = await _dio.post<String>(
        '$storeBase$path',
        data: form,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          listFormat: ListFormat.multi,
          headers: {
            if (cookies != null) 'Cookie': _cookieHeader(cookies),
            'Referer': ?referer,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
      return _decodeCommunityJson(resp, 'store$path');
    } on DioException catch (e) {
      dlog('  ✗ store$path network: ${e.type.name} ${e.response?.statusCode ?? ''}');
      rethrow;
    }
  }

  String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

class SteamApiException implements Exception {
  final int eresult;
  final String message;
  final String method;

  /// HTTP status when the failure was a bare non-2xx with no eresult (an
  /// expired token surfaces as a naked 401/403); null for eresult failures.
  /// Lets callers detect a dead session structurally ([isSessionDeadError])
  /// instead of string-matching 'HTTP 401' out of [message].
  final int? httpStatus;

  SteamApiException(this.eresult, this.message, this.method, {this.httpStatus});
  @override
  String toString() => 'SteamApiException($method): $message (eresult=$eresult)';
}

/// True when [e] means the account's web session is dead — a missing/expired
/// access token or a stale community cookie — so the caller should route to
/// re-auth (and retry) instead of surfacing the raw error.
bool isSessionDeadError(Object e) =>
    e is MissingAccessTokenException ||
    e is CommunityAuthException ||
    (e is SteamApiException && (e.httpStatus == 401 || e.httpStatus == 403));

/// steamcommunity.com rejected the request at the HTTP level — a redirect
/// (to the login page) or a bare 401/403. The session cookie is stale or
/// missing; callers must route to re-auth instead of parsing the (usually
/// empty) body as a success-shaped `{}`.
class CommunityAuthException implements Exception {
  final int status;
  final String path;
  const CommunityAuthException(this.status, this.path);
  @override
  String toString() => 'CommunityAuthException($path: HTTP $status)';
}
