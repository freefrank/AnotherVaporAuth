import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Test-only mint for entitlement JWTs, mirroring the worker's format.
class EntitlementMint {
  final ed.KeyPair keys = ed.generateKey();

  Uint8List get publicKey => Uint8List.fromList(keys.publicKey.bytes);

  String _seg(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  String mint({
    required DateTime now,
    String sub = 'user-1',
    String chan = 'play',
    String tier = 'pro',
    String dev = 'device-1',
    String cls = 'android',
    DateTime? iat,
    DateTime? exp,
    DateTime? pro,
    bool lifetime = false,
  }) {
    int sec(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
    final h = _seg({'alg': 'EdDSA', 'typ': 'JWT'});
    final p = _seg({
      'sub': sub,
      'chan': chan,
      'tier': tier,
      'dev': dev,
      'cls': cls,
      'iat': sec(iat ?? now.subtract(const Duration(minutes: 5))),
      'exp': sec(exp ?? now.add(const Duration(hours: 24))),
      'pro': lifetime ? 0 : sec(pro ?? now.add(const Duration(days: 30))),
    });
    final sig = ed.sign(keys.privateKey, ascii.encode('$h.$p'));
    return '$h.$p.${base64Url.encode(sig).replaceAll('=', '')}';
  }
}
