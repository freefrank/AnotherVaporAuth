import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/proto/protobuf_wire.dart';

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

  SteamApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              followRedirects: false,
              validateStatus: (s) => s != null && s < 500,
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

    final eresult =
        int.tryParse(resp.headers.value('x-eresult') ?? '') ?? 1;
    if (eresult != 1) {
      final msg = resp.headers.value('x-error_message');
      throw SteamApiException(eresult, msg ?? 'EResult $eresult', method);
    }
    return ProtoReader(Uint8List.fromList(resp.data ?? const []));
  }

  /// GET against steamcommunity.com (mobileconf), returning decoded JSON.
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
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
    if (body.isEmpty) return const {};
    return jsonDecode(body) as Map<String, dynamic>;
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
