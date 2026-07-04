import 'dart:convert';
import 'dart:typed_data';

/// Normalizes common maFile variants into the shape used by SteamAuth/SDA.
///
/// The model layer intentionally preserves unknown keys for round-tripping, so
/// import-time compatibility lives here instead of inside SteamGuardAccount.
class MaFileNormalizer {
  static const _steamIdKeys = [
    'steamid',
    'steam64',
    'steam_id64',
    'steamID64',
    'SteamID64',
    'sbeamid',
  ];

  static const _uriKeys = ['uri', 'otp_uri', 'otpauth_uri', 'steam_uri', 'url'];

  static Map<String, dynamic> normalize(
    Map<String, dynamic> json, {
    String? sourceName,
  }) {
    final normalized = Map<String, dynamic>.from(json);
    _normalizeSteamId(normalized, sourceName: sourceName);
    _normalizeSharedSecret(normalized);
    return normalized;
  }

  static void _normalizeSteamId(
    Map<String, dynamic> json, {
    String? sourceName,
  }) {
    final session = _sessionMap(json);
    if (_asInt(session['SteamID']) != 0) return;

    for (final key in _steamIdKeys) {
      final steamId = _asInt(json[key]);
      if (steamId != 0) {
        session['SteamID'] = steamId;
        json['Session'] = session;
        return;
      }
      // Some exporters (Steam++/Watt Toolkit variants) store the 64-bit SteamID
      // base64-encoded rather than as a decimal string.
      final fromB64 = _steamIdFromBase64(json[key]);
      if (fromB64 != 0) {
        session['SteamID'] = fromB64;
        json['Session'] = session;
        return;
      }
    }

    final fromName = _steamIdFromSourceName(sourceName);
    if (fromName != 0) {
      session['SteamID'] = fromName;
      json['Session'] = session;
    }
  }

  static Map<String, dynamic> _sessionMap(Map<String, dynamic> json) {
    final session = json['Session'];
    if (session is Map<String, dynamic>) {
      return Map<String, dynamic>.from(session);
    }
    if (session is Map) {
      return Map<String, dynamic>.from(session);
    }
    return <String, dynamic>{};
  }

  /// Decodes a base64-encoded 8-byte SteamID (either endianness) if it lands in
  /// the individual-account SteamID64 range; else 0.
  static int _steamIdFromBase64(dynamic value) {
    if (value is! String || value.trim().isEmpty) return 0;
    Uint8List bytes;
    try {
      bytes = base64.decode(value.trim());
    } on FormatException {
      return 0;
    }
    if (bytes.length != 8) return 0;
    final bd = ByteData.sublistView(bytes);
    for (final id in [bd.getUint64(0, Endian.little), bd.getUint64(0)]) {
      // Individual SteamID64s start at 0x0110000100000000 (76561197960265728).
      if (id >= 76561197960265728 && id < 76561202000000000) return id;
    }
    return 0;
  }

  static int _steamIdFromSourceName(String? sourceName) {
    if (sourceName == null) return 0;
    final match = RegExp(
      r'(^|[^0-9])(7656119[0-9]{10})([^0-9]|$)',
    ).firstMatch(sourceName);
    return match == null ? 0 : int.tryParse(match.group(2)!) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static void _normalizeSharedSecret(Map<String, dynamic> json) {
    final uriSecret = _sharedSecretFromUri(json);
    if (uriSecret != null) {
      json['shared_secret'] = uriSecret;
      return;
    }

    final secret = json['shared_secret'];
    if (secret is! String || secret.trim().isEmpty) return;

    final normalized = _normalizeSecretValue(secret);
    if (normalized != null) json['shared_secret'] = normalized;
  }

  static String? _sharedSecretFromUri(Map<String, dynamic> json) {
    for (final key in _uriKeys) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) continue;

      final secret = _extractSecretFromUri(value.trim());
      if (secret == null || secret.isEmpty) continue;

      return _base32ToBase64(secret) ?? _normalizeSecretValue(secret) ?? secret;
    }
    return null;
  }

  static String? _extractSecretFromUri(String value) {
    final steamUriMatch = RegExp(
      r'^steam://(.+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (steamUriMatch != null) {
      return Uri.decodeComponent(
        steamUriMatch.group(1)!.replaceFirst(RegExp(r'^/+'), ''),
      );
    }

    final parsed = Uri.tryParse(value);
    if (parsed != null) {
      final querySecret = parsed.queryParameters['secret'];
      if (querySecret != null && querySecret.isNotEmpty) return querySecret;
    }

    final match = RegExp(
      r'(?:^|[?&])secret=([^&]+)',
      caseSensitive: false,
    ).firstMatch(value);
    return match == null ? null : Uri.decodeComponent(match.group(1)!);
  }

  static String? _normalizeSecretValue(String value) {
    final trimmed = value.trim();
    final base64Bytes = _tryBase64Decode(trimmed);
    if (base64Bytes != null && base64Bytes.length == 20) return trimmed;

    return _base32ToBase64(trimmed) ??
        (base64Bytes == null ? null : base64.encode(base64Bytes));
  }

  static Uint8List? _tryBase64Decode(String value) {
    try {
      return Uint8List.fromList(base64.decode(value));
    } on FormatException {
      return null;
    }
  }

  static String? _base32ToBase64(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('=', '')
        .toUpperCase();
    if (cleaned.isEmpty || !RegExp(r'^[A-Z2-7]+$').hasMatch(cleaned)) {
      return null;
    }

    var buffer = 0;
    var bitsLeft = 0;
    final bytes = <int>[];

    for (final codeUnit in cleaned.codeUnits) {
      final value = _base32Value(codeUnit);
      if (value < 0) return null;
      buffer = (buffer << 5) | value;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 0xFF);
        bitsLeft -= 8;
      }
    }

    return bytes.isEmpty ? null : base64.encode(bytes);
  }

  static int _base32Value(int codeUnit) {
    if (codeUnit >= 65 && codeUnit <= 90) return codeUnit - 65;
    if (codeUnit >= 50 && codeUnit <= 55) return codeUnit - 24;
    return -1;
  }
}
