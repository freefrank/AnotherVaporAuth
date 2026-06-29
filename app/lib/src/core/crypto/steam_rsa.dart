import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// RSA encryption of the Steam password using the public key returned by
/// `GetPasswordRSAPublicKey` (modulus + exponent as hex strings).
/// PKCS#1 v1.5 padding, result base64 encoded — matches SteamKit / Steam web.
class SteamRsa {
  static String encryptPassword(
      String password, String modulusHex, String exponentHex) {
    final modulus = _hexToBigInt(modulusHex);
    final exponent = _hexToBigInt(exponentHex);
    final pub = RSAPublicKey(modulus, exponent);

    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(pub));
    final out = cipher.process(
      Uint8List.fromList(utf8.encode(password)),
    );
    return base64.encode(out);
  }

  static BigInt _hexToBigInt(String hex) =>
      BigInt.parse(hex, radix: 16);
}
