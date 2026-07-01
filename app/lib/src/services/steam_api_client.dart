import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/protocol/eresult.dart';
import '../core/proto/protobuf_wire.dart';
import 'debug_log.dart';

/// Thin HTTP client for Steam's web APIs.
///
/// Handles the two transports SDA needs:
///  - `api.steampowered.com/<Iface>/<Method>/v1` protobuf calls
///    (IAuthenticationService, ITwoFactorService).
///  - `steamcommunity.com/mobileconf/*` confirmation calls (plain query + cookies).
class SteamApiClient {
  static const String apiBase = 'https://api.steampowered.com';
  static const String communityBase = 'https://steamcommunity.com';

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
    final encoded = base64.encode(request.toBytes());
    final query = <String, dynamic>{
      'access_token': ?accessToken,
    };

    dlog('→ ${useGet ? 'GET' : 'POST'} $iface/$method '
        '(${request.toBytes().length}B${accessToken != null ? ', +token' : ''})');
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

      final eresult = int.tryParse(resp.headers.value('x-eresult') ?? '') ?? 1;
      final bytes = resp.data?.length ?? 0;
      dlog('← $method  HTTP ${resp.statusCode}  '
          'eresult=${eresultLabel(eresult)}  ${bytes}B');
      if (eresult != 1) {
        final msg = resp.headers.value('x-error_message');
        dlog('  ✗ $method error: ${msg ?? eresultLabel(eresult)}');
        throw SteamApiException(eresult, msg ?? eresultLabel(eresult), method);
      }
      return ProtoReader(Uint8List.fromList(resp.data ?? const []));
    } on DioException catch (e) {
      dlog('  ✗ $method network: ${e.type.name} ${e.response?.statusCode ?? ''} ${e.message ?? ''}');
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
      final body = resp.data ?? '';
      dlog('← $path  HTTP ${resp.statusCode}  ${body.length}B');
      if (body.isEmpty) return const {};
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['success'] != true) {
        dlog('  ⚠ $path success=${json['success']} '
            '${json['message'] ?? json['needauth'] ?? ''}');
      }
      return json;
    } on DioException catch (e) {
      dlog('  ✗ $path network: ${e.type.name} ${e.response?.statusCode ?? ''}');
      rethrow;
    }
  }

  /// GETs a community URL and returns the raw response body (HTML/text). Used to
  /// scrape page globals like `g_rgAppContextData` / `g_rgWalletInfo`.
  Future<String> communityGetText(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? cookies,
  }) async {
    dlog('→ GET(text) $path');
    final resp = await _dio.get<String>(
      path.startsWith('http') ? path : '$communityBase$path',
      queryParameters: query,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          if (cookies != null) 'Cookie': _cookieHeader(cookies),
          'X-Requested-With': 'com.valvesoftware.android.steam.community',
        },
      ),
    );
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
      final body = resp.data ?? '';
      dlog('← $path  HTTP ${resp.statusCode}  ${body.length}B');
      if (body.isEmpty) return const {};
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['success'] != true) {
        dlog('  ⚠ $path success=${json['success']} '
            '${json['message'] ?? json['needauth'] ?? ''}');
      }
      return json;
    } on DioException catch (e) {
      dlog('  ✗ $path network: ${e.type.name} ${e.response?.statusCode ?? ''}');
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
  SteamApiException(this.eresult, this.message, this.method);
  @override
  String toString() => 'SteamApiException($method): $message (eresult=$eresult)';
}
