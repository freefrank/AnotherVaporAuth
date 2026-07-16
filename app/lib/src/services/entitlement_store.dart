import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'debug_log.dart';

/// HTTP shim for the entitlement worker (infra/entitlement-worker).
/// All endpoints that succeed return a fresh EdDSA entitlement JWT; the
/// caller (EntitlementTokenController) parses, persists and adopts it.

/// Base URL of the deployed worker. Placeholder until the worker goes live.
const kEntitlementApiBase = 'https://api.ava.dotslash.pro';

/// Ed25519 public key (base64, 32 bytes) matching the worker's signing key.
/// Placeholder until the production keypair is generated at deploy time —
/// while empty, every stored token fails verification and the app stays
/// free-tier, which is the safe direction.
const kEntitlementPublicKeyB64 = '';

Uint8List entitlementPublicKeyBytes() {
  try {
    return base64.decode(kEntitlementPublicKeyB64);
  } catch (_) {
    return Uint8List(0);
  }
}

/// Non-2xx reply from the worker. [status] 403 means the entitlement is
/// positively gone (revoked / kicked device / ended) rather than unreachable.
class EntitlementApiException implements Exception {
  final int status;

  /// Worker error code ('revoked' | 'device_revoked' | 'entitlement_ended' |
  /// 'order_bound' | …) — surfaced in UI copy where it matters.
  final String code;

  EntitlementApiException(this.status, this.code);

  bool get isTerminal => status == 403;

  @override
  String toString() => 'EntitlementApiException($status, $code)';
}

abstract class EntitlementApi {
  /// Rotates a (possibly expired but structurally valid) token.
  Future<String> refresh(String token, String deviceId);

  /// Play channel: Google id_token + Billing purchaseToken → token.
  Future<String> verifyPlay({
    required String idToken,
    required String purchaseToken,
    required String deviceId,
    required String deviceClass,
  });

  /// cn channel: Afdian order number → token.
  Future<String> redeemAfdian({
    required String orderNo,
    required String deviceId,
    required String deviceClass,
  });

  /// Beta lifetime unlock code → token.
  Future<String> redeemBeta({
    required String code,
    required String deviceId,
    required String deviceClass,
  });

  /// Claims the VIP entitlement the AdMob SSV callback created for this
  /// device (rewarded-ad unlock). 404 'no_vip' until the callback lands.
  Future<String> claimVip({
    required String deviceId,
    required String deviceClass,
  });
}

class DioEntitlementApi implements EntitlementApi {
  final Dio _dio;

  DioEntitlementApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kEntitlementApiBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              // Parse error bodies ourselves instead of throwing blind.
              validateStatus: (_) => true,
            ));

  @override
  Future<String> refresh(String token, String deviceId) =>
      _post('/v1/token/refresh', {'token': token, 'device_id': deviceId});

  @override
  Future<String> verifyPlay({
    required String idToken,
    required String purchaseToken,
    required String deviceId,
    required String deviceClass,
  }) =>
      _post('/v1/play/verify', {
        'id_token': idToken,
        'purchase_token': purchaseToken,
        'device_id': deviceId,
        'device_class': deviceClass,
      });

  @override
  Future<String> redeemAfdian({
    required String orderNo,
    required String deviceId,
    required String deviceClass,
  }) =>
      _post('/v1/afdian/redeem', {
        'order_no': orderNo,
        'device_id': deviceId,
        'device_class': deviceClass,
      });

  @override
  Future<String> redeemBeta({
    required String code,
    required String deviceId,
    required String deviceClass,
  }) =>
      _post('/v1/beta/redeem', {
        'code': code,
        'device_id': deviceId,
        'device_class': deviceClass,
      });

  @override
  Future<String> claimVip({
    required String deviceId,
    required String deviceClass,
  }) =>
      _post('/v1/vip/claim', {
        'device_id': deviceId,
        'device_class': deviceClass,
      });

  Future<String> _post(String path, Map<String, Object?> body) async {
    final resp = await _dio.post<Map<String, dynamic>>(path, data: body);
    final status = resp.statusCode ?? 0;
    final data = resp.data;
    if (status >= 200 && status < 300) {
      final token = data?['token'];
      if (token is String && token.isNotEmpty) return token;
      throw EntitlementApiException(status, 'malformed_response');
    }
    final code = data?['error'];
    dlog('entitlement: $path HTTP $status ${code ?? ''}');
    throw EntitlementApiException(
        status, code is String ? code : 'http_$status');
  }
}

/// Generates the stable per-install device id (crypto-random, hex).
String newDeviceId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
