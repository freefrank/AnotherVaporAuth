import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Offline verification and evaluation of AVA Pro entitlement tokens.
///
/// The entitlement worker issues short-lived (24h) EdDSA-signed JWTs; the
/// app verifies them against an embedded Ed25519 public key with no network
/// round-trip. This file is pure Dart: parsing + signature check + the
/// clock-vs-claims state machine. Refresh scheduling and persistence live
/// in services/entitlement_store.dart.
///
/// Claims (mirrored by the worker — keep in sync):
///   sub  string  subject (Google sub / Afdian user_id / beta code id)
///   chan string  'play' | 'afdian' | 'beta'
///   tier string  'pro' | 'vip'  (vip = rewarded-ad unlock)
///   dev  string  device id the token is bound to
///   cls  string  device class ('android' | 'windows' | 'linux' | 'macos')
///   iat  int     issued-at, epoch seconds
///   exp  int     token validity end (refresh deadline), epoch seconds
///   pro  int     entitlement end, epoch seconds; 0 = lifetime

enum EntitlementChannel { play, afdian, beta, unknown }

enum EntitlementTier { pro, vip }

/// What the UI gates on.
enum ProStatus { pro, vip, free }

/// Offline grace after the token's refresh deadline (exp) during which the
/// last known entitlement keeps working.
const entitlementGrace = Duration(days: 7);

/// Tolerance for tokens whose iat is ahead of the local clock (device clock
/// drift). Beyond it the token is treated as invalid — a far-future iat
/// means either a bogus token or a rolled-back local clock.
const entitlementClockSkew = Duration(hours: 48);

class EntitlementToken {
  final EntitlementChannel channel;
  final EntitlementTier tier;
  final String subject;
  final String deviceId;
  final String deviceClass;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// Entitlement end; null = lifetime (claim value 0).
  final DateTime? proUntil;

  /// The verbatim JWT, kept for refresh calls.
  final String raw;

  const EntitlementToken({
    required this.channel,
    required this.tier,
    required this.subject,
    required this.deviceId,
    required this.deviceClass,
    required this.issuedAt,
    required this.expiresAt,
    required this.proUntil,
    required this.raw,
  });

  /// Parses and signature-checks [raw]. Returns null on any structural,
  /// type or signature problem — a stored token must never crash the app.
  static EntitlementToken? tryParse(String raw,
      {required Uint8List publicKey}) {
    try {
      final parts = raw.split('.');
      if (parts.length != 3) return null;

      final header = _decodeJsonSegment(parts[0]);
      // Exact-match the algorithm: anything else (none, HS256, …) is an
      // algorithm-confusion attempt or garbage.
      if (header == null || header['alg'] != 'EdDSA') return null;

      final claims = _decodeJsonSegment(parts[1]);
      if (claims == null) return null;

      final sig = _decodeBytes(parts[2]);
      if (sig == null || sig.length != 64) return null;
      final message = ascii.encode('${parts[0]}.${parts[1]}');
      if (!ed.verify(ed.PublicKey(publicKey), message, sig)) return null;

      final sub = claims['sub'];
      final chan = claims['chan'];
      final tier = claims['tier'];
      final dev = claims['dev'];
      final cls = claims['cls'];
      final iat = claims['iat'];
      final exp = claims['exp'];
      final proSec = claims['pro'];
      if (sub is! String || dev is! String || cls is! String) return null;
      if (iat is! int || exp is! int || proSec is! int || proSec < 0) {
        return null;
      }

      return EntitlementToken(
        channel: switch (chan) {
          'play' => EntitlementChannel.play,
          'afdian' => EntitlementChannel.afdian,
          'beta' => EntitlementChannel.beta,
          // Unknown channel names stay valid (forward compatibility): the
          // signature already proves the worker issued this token.
          String() => EntitlementChannel.unknown,
          _ => throw const FormatException(),
        },
        tier: switch (tier) {
          'pro' => EntitlementTier.pro,
          'vip' => EntitlementTier.vip,
          _ => throw const FormatException(),
        },
        subject: sub,
        deviceId: dev,
        deviceClass: cls,
        issuedAt: _epoch(iat),
        expiresAt: _epoch(exp),
        proUntil: proSec == 0 ? null : _epoch(proSec),
        raw: raw,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime _epoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  static Map<String, dynamic>? _decodeJsonSegment(String segment) {
    final bytes = _decodeBytes(segment);
    if (bytes == null) return null;
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static Uint8List? _decodeBytes(String segment) {
    try {
      return base64Url.decode(base64Url.normalize(segment));
    } catch (_) {
      return null;
    }
  }
}

/// The evaluated meaning of a stored token at wall-clock [now].
class EntitlementState {
  final ProStatus status;

  /// True whenever the store should hit the worker: token past its refresh
  /// deadline (grace or expired), entitlement ended (a renewal may extend
  /// it), or the clock looks tampered.
  final bool needsRefresh;

  const EntitlementState(this.status, {required this.needsRefresh});
}

EntitlementState evaluateEntitlement(
  EntitlementToken? token,
  DateTime now, {
  Duration grace = entitlementGrace,
  Duration clockSkew = entitlementClockSkew,
}) {
  const freeRefresh = EntitlementState(ProStatus.free, needsRefresh: true);
  if (token == null) {
    return const EntitlementState(ProStatus.free, needsRefresh: false);
  }
  // Token "from the future": bogus, or the clock was rolled back (which
  // would otherwise stretch the grace window indefinitely).
  if (token.issuedAt.isAfter(now.add(clockSkew))) return freeRefresh;
  // Entitlement period over — only a refresh (renewal) can revive it.
  final proUntil = token.proUntil;
  if (proUntil != null && !now.isBefore(proUntil)) return freeRefresh;

  final status =
      token.tier == EntitlementTier.vip ? ProStatus.vip : ProStatus.pro;
  if (!now.isAfter(token.expiresAt)) {
    return EntitlementState(status, needsRefresh: false);
  }
  if (!now.isAfter(token.expiresAt.add(grace))) {
    // Offline grace: keep the last proven entitlement while refresh fails.
    return EntitlementState(status, needsRefresh: true);
  }
  return freeRefresh;
}
