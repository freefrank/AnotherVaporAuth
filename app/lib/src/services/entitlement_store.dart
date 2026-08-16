import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'debug_log.dart';

/// HTTP shim for the entitlement worker (infra/entitlement-worker).
/// All endpoints that succeed return a fresh EdDSA entitlement JWT; the
/// caller (EntitlementTokenController) parses, persists and adopts it.

/// Base URL of the deployed worker. Placeholder until the worker goes live.
const kEntitlementApiBase = 'https://api.ava.dotslash.pro';

/// Ed25519 public key (base64, 32 bytes) matching the worker's signing key
/// (deployed 2026-07-16; private key lives only in worker secrets + the
/// ava-entitlement-signing.pem backup next to the upload keystore).
const kEntitlementPublicKeyB64 = 'xBGC2NnMMjKlH8slzvXT9auGApPNTlUTBvw/tsLCrz8=';

Uint8List entitlementPublicKeyBytes() {
  try {
    return base64.decode(kEntitlementPublicKeyB64);
  } catch (_) {
    return Uint8List(0);
  }
}

/// One occupied device-class slot on an entitlement. The worker only ever
/// discloses classes + timestamps — never device ids (a code holder must not
/// learn another holder's device id).
class EntitlementActivation {
  /// Worker device_class vocabulary: 'android' | 'windows' | 'linux' | 'macos'.
  final String deviceClass;
  final DateTime activatedAt;

  /// Only /v1/entitlement/status sets this (error payloads carry no
  /// device identity to compare against).
  final bool thisDevice;

  EntitlementActivation({
    required this.deviceClass,
    required this.activatedAt,
    this.thisDevice = false,
  });

  /// Null on any shape mismatch — one bad entry must not discard the reply.
  static EntitlementActivation? tryParse(Object? json) {
    if (json is! Map) return null;
    final cls = json['device_class'];
    final at = json['activated_at'];
    if (cls is! String || at is! int) return null;
    return EntitlementActivation(
      deviceClass: cls,
      activatedAt: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
      thisDevice: json['this_device'] == true,
    );
  }
}

List<EntitlementActivation>? _activationsFrom(Map<String, dynamic>? data) {
  final raw = data?['activations'];
  if (raw is! List) return null;
  return raw
      .map(EntitlementActivation.tryParse)
      .whereType<EntitlementActivation>()
      .toList();
}

/// Non-2xx reply from the worker. [status] 403 means the entitlement is
/// positively gone (revoked / kicked device / ended) rather than unreachable.
class EntitlementApiException implements Exception {
  final int status;

  /// Worker error code ('revoked' | 'device_revoked' | 'entitlement_ended' |
  /// 'order_bound' | …) — surfaced in UI copy where it matters.
  final String code;

  /// Occupied slots, when the error body carries them ('code_activation_limit'
  /// does — it turns a dead-end refusal into an actionable one).
  final List<EntitlementActivation>? activations;

  /// Masked email of the account holding this purchase ('purchase_token_bound'
  /// carries it): the actionable half of a multi-account refusal.
  final String? boundHint;

  EntitlementApiException(this.status, this.code,
      {this.activations, this.boundHint});

  bool get isTerminal => status == 403;

  @override
  String toString() => 'EntitlementApiException($status, $code)';
}

/// Reply of POST /v1/entitlement/status — feeds the paywall's status card.
class EntitlementStatus {
  final String channel;
  final String tier;

  /// Epoch seconds; 0 = lifetime (mirrors the JWT 'pro' claim).
  final int proUntil;
  final List<EntitlementActivation> activations;

  EntitlementStatus({
    required this.channel,
    required this.tier,
    required this.proUntil,
    required this.activations,
  });
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

  /// Which device-class slots the token's entitlement occupies. The worker
  /// verifies the signature but ignores expiry (same policy as refresh).
  /// Errors: 'invalid_token' | 'entitlement_ended' | 'revoked'.
  Future<EntitlementStatus> status(String token);
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

  @override
  Future<EntitlementStatus> status(String token) async {
    const path = '/v1/entitlement/status';
    final resp = await _dio.post<Map<String, dynamic>>(path, data: {
      'token': token,
    });
    final status = resp.statusCode ?? 0;
    final data = resp.data;
    if (status >= 200 && status < 300) {
      final channel = data?['channel'];
      final tier = data?['tier'];
      final proUntil = data?['pro_until'];
      if (channel is! String || tier is! String) {
        throw EntitlementApiException(status, 'malformed_response');
      }
      return EntitlementStatus(
        channel: channel,
        tier: tier,
        proUntil: proUntil is int ? proUntil : 0,
        activations: _activationsFrom(data) ?? const [],
      );
    }
    throw _error(path, status, data);
  }

  Future<String> _post(String path, Map<String, Object?> body) async {
    final resp = await _dio.post<Map<String, dynamic>>(path, data: body);
    final status = resp.statusCode ?? 0;
    final data = resp.data;
    if (status >= 200 && status < 300) {
      final token = data?['token'];
      if (token is String && token.isNotEmpty) return token;
      throw EntitlementApiException(status, 'malformed_response');
    }
    throw _error(path, status, data);
  }

  EntitlementApiException _error(
      String path, int status, Map<String, dynamic>? data) {
    final code = data?['error'];
    dlog('entitlement: $path HTTP $status ${code ?? ''}');
    final hint = data?['bound_hint'];
    return EntitlementApiException(status, code is String ? code : 'http_$status',
        activations: _activationsFrom(data),
        boundHint: hint is String && hint.isNotEmpty ? hint : null);
  }
}

/// Maps the running platform onto the worker's device_class vocabulary
/// (DEVICE_CLASSES in infra/entitlement-worker/src/logic.ts — keep in sync:
/// 'android' | 'windows' | 'linux' | 'macos'). The class keys the one-
/// device-per-class slot on the worker, so sending the wrong one consumes
/// another platform's slot.
String deviceClassForPlatform() => switch (Platform.operatingSystem) {
      'android' => 'android',
      'windows' => 'windows',
      'linux' => 'linux',
      'macos' => 'macos',
      // Unsupported platform (no such build target today): keep the
      // historical default rather than sending a value the worker rejects.
      _ => 'android',
    };

/// Generates the stable per-install device id (crypto-random, hex).
String newDeviceId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
