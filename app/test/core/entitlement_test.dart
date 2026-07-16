import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/entitlement.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final keys = ed.generateKey();
  final publicKey = Uint8List.fromList(keys.publicKey.bytes);
  final otherKeys = ed.generateKey();

  // 2026-07-15T12:00:00Z, the "now" all clock-relative tests hang off.
  final now = DateTime.utc(2026, 7, 15, 12);
  int sec(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  String seg(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  /// Signs a token with [keys] (or [signer]) over standard claims,
  /// overridable per test.
  String mint({
    Map<String, dynamic>? header,
    Map<String, dynamic>? overrides,
    ed.PrivateKey? signer,
    DateTime? iat,
    DateTime? exp,
    DateTime? pro,
    bool lifetime = false,
    String tier = 'pro',
  }) {
    final claims = <String, dynamic>{
      'sub': 'user-1',
      'chan': 'play',
      'tier': tier,
      'dev': 'device-1',
      'cls': 'android',
      'iat': sec(iat ?? now.subtract(const Duration(hours: 1))),
      'exp': sec(exp ?? now.add(const Duration(hours: 23))),
      'pro': lifetime ? 0 : sec(pro ?? now.add(const Duration(days: 20))),
      ...?overrides,
    };
    final h = seg(header ?? {'alg': 'EdDSA', 'typ': 'JWT'});
    final p = seg(claims);
    final sig = ed.sign(signer ?? keys.privateKey, ascii.encode('$h.$p'));
    return '$h.$p.${base64Url.encode(sig).replaceAll('=', '')}';
  }

  EntitlementToken? parse(String raw) =>
      EntitlementToken.tryParse(raw, publicKey: publicKey);

  group('EntitlementToken.tryParse', () {
    test('valid token round-trips all claims', () {
      final t = parse(mint())!;
      expect(t.channel, EntitlementChannel.play);
      expect(t.tier, EntitlementTier.pro);
      expect(t.subject, 'user-1');
      expect(t.deviceId, 'device-1');
      expect(t.deviceClass, 'android');
      expect(t.issuedAt, now.subtract(const Duration(hours: 1)));
      expect(t.expiresAt, now.add(const Duration(hours: 23)));
      expect(t.proUntil, now.add(const Duration(days: 20)));
    });

    test('pro claim 0 means lifetime (proUntil null)', () {
      expect(parse(mint(lifetime: true))!.proUntil, isNull);
    });

    test('unknown channel names parse as unknown (forward compat)', () {
      expect(parse(mint(overrides: {'chan': 'steam-deck'}))!.channel,
          EntitlementChannel.unknown);
    });

    test('rejects a token signed with a different key', () {
      expect(parse(mint(signer: otherKeys.privateKey)), isNull);
    });

    test('rejects a tampered payload', () {
      final good = mint();
      final parts = good.split('.');
      final claims =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      claims['pro'] = 0; // upgrade yourself to lifetime
      final forged = '${parts[0]}.${seg(claims)}.${parts[2]}';
      expect(parse(forged), isNull);
    });

    test('rejects non-EdDSA algorithms (alg confusion)', () {
      expect(parse(mint(header: {'alg': 'none'})), isNull);
      expect(parse(mint(header: {'alg': 'HS256'})), isNull);
      expect(parse(mint(header: {'typ': 'JWT'})), isNull);
    });

    test('rejects wrong types and missing claims', () {
      expect(parse(mint(overrides: {'iat': 'yesterday'})), isNull);
      expect(parse(mint(overrides: {'sub': 7})), isNull);
      expect(parse(mint(overrides: {'tier': 'ultra'})), isNull);
      expect(parse(mint(overrides: {'pro': -5})), isNull);
      expect(parse(mint(overrides: {'dev': null})), isNull);
    });

    test('malformed inputs return null without throwing', () {
      for (final garbage in [
        '',
        'a.b',
        'a.b.c.d',
        'not-base64!!!.${'x' * 10}.sig',
        '${seg([1, 2, 3])}.${seg({'a': 1})}.AAAA', // header not an object
        mint().substring(0, 40),
        String.fromCharCodes(List.filled(100000, 65)),
      ]) {
        expect(parse(garbage), isNull, reason: garbage.length.toString());
      }
    });
  });

  group('evaluateEntitlement', () {
    EntitlementState eval(String raw, DateTime at) =>
        evaluateEntitlement(parse(raw), at);

    test('no token is free and quiet (nothing to refresh)', () {
      final s = evaluateEntitlement(null, now);
      expect(s.status, ProStatus.free);
      expect(s.needsRefresh, isFalse);
    });

    test('fresh token grants its tier without refresh', () {
      expect(eval(mint(), now).status, ProStatus.pro);
      expect(eval(mint(), now).needsRefresh, isFalse);
      expect(eval(mint(tier: 'vip'), now).status, ProStatus.vip);
    });

    test('past exp but inside grace keeps the tier and asks for refresh', () {
      final t = mint(exp: now.subtract(const Duration(days: 2)));
      final s = eval(t, now);
      expect(s.status, ProStatus.pro);
      expect(s.needsRefresh, isTrue);
    });

    test('grace boundary: entitled at exp+7d, free one second later', () {
      final exp = now.subtract(const Duration(days: 7));
      final t = mint(exp: exp, pro: now.add(const Duration(days: 30)));
      expect(eval(t, exp.add(entitlementGrace)).status, ProStatus.pro);
      expect(
          eval(t, exp.add(entitlementGrace).add(const Duration(seconds: 1)))
              .status,
          ProStatus.free);
    });

    test('entitlement end (pro) beats token validity: expired sub is free',
        () {
      final t = mint(
          pro: now.subtract(const Duration(minutes: 1)),
          exp: now.add(const Duration(hours: 12)));
      final s = eval(t, now);
      expect(s.status, ProStatus.free);
      expect(s.needsRefresh, isTrue, reason: 'a renewal may extend it');
    });

    test('lifetime token stays pro far past exp+grace only via refresh path',
        () {
      final t = mint(lifetime: true, exp: now.add(const Duration(hours: 23)));
      expect(eval(t, now).status, ProStatus.pro);
      // Even lifetime drops to free once exp+grace passes without refresh —
      // that is what keeps a revoked device from working offline forever.
      expect(eval(t, now.add(const Duration(days: 9))).status, ProStatus.free);
    });

    test('clock rollback: far-future iat is free, small skew tolerated', () {
      final future = mint(iat: now.add(const Duration(days: 3)));
      expect(eval(future, now).status, ProStatus.free);
      expect(eval(future, now).needsRefresh, isTrue);

      final slightSkew = mint(iat: now.add(const Duration(hours: 47)));
      expect(eval(slightSkew, now).status, ProStatus.pro);
    });
  });
}
