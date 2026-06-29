import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Steam Guard time-based code + mobile confirmation signing.
///
/// Logic-equivalent to the C# `SteamGuardAccount.GenerateSteamGuardCode`
/// and `GenerateConfirmationHashForTime` (geel9/SteamAuth).
class SteamTotp {
  /// Steam's custom code alphabet (26 chars).
  static const String _codeChars = '23456789BCDFGHJKMNPQRTVWXY';

  /// Generates the 5-character Steam Guard login code for [sharedSecret]
  /// (base64) at the given Steam server [time] (unix seconds).
  static String generateAuthCode(String sharedSecret, int time) {
    final key = base64.decode(sharedSecret.trim());

    // 8-byte big-endian counter = time / 30.
    var counter = time ~/ 30;
    final timeBytes = Uint8List(8);
    for (var i = 7; i >= 0; i--) {
      timeBytes[i] = counter & 0xFF;
      counter >>= 8;
    }

    final hmac = Hmac(sha1, key).convert(timeBytes).bytes;
    final start = hmac[19] & 0x0F;
    var fullCode = ((hmac[start] & 0x7F) << 24) |
        ((hmac[start + 1] & 0xFF) << 16) |
        ((hmac[start + 2] & 0xFF) << 8) |
        (hmac[start + 3] & 0xFF);

    final buffer = StringBuffer();
    for (var i = 0; i < 5; i++) {
      buffer.write(_codeChars[fullCode % _codeChars.length]);
      fullCode ~/= _codeChars.length;
    }
    return buffer.toString();
  }

  /// Generates the base64 confirmation hash (the `k` query param) for a given
  /// [time], [tag] and [identitySecret] (base64).
  ///
  /// Buffer = 8-byte big-endian time, optionally followed by the tag bytes
  /// (tag truncated to 32 chars by Steam convention). HMAC-SHA1 with the
  /// identity secret, base64 encoded.
  static String generateConfirmationHash(
    int time,
    String tag,
    String identitySecret,
  ) {
    final key = base64.decode(identitySecret.trim());
    final tagBytes = tag.isEmpty
        ? const <int>[]
        : utf8.encode(tag.length > 32 ? tag.substring(0, 32) : tag);

    final buffer = Uint8List(8 + tagBytes.length);
    var t = time;
    for (var i = 7; i >= 0; i--) {
      buffer[i] = t & 0xFF;
      t >>= 8;
    }
    for (var i = 0; i < tagBytes.length; i++) {
      buffer[8 + i] = tagBytes[i];
    }

    final hmac = Hmac(sha1, key).convert(buffer).bytes;
    return base64.encode(hmac);
  }

  /// Seconds remaining in the current 30s TOTP window for [time].
  static int secondsRemaining(int time) => 30 - (time % 30);
}
