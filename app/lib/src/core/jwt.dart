import 'dart:convert';

/// Decodes the payload (second segment) of a JWT without any signature
/// verification — Steam's tokens are only *read* client-side, for claims like
/// `exp` (staleness) and `sub` (steamid). Handles the base64url alphabet and
/// missing padding. Returns null on any malformation: absent/empty input,
/// too few segments, bad base64, non-JSON or non-object payload.
Map<String, dynamic>? decodeJwtPayload(String? jwt) {
  if (jwt == null || jwt.isEmpty) return null;
  final parts = jwt.split('.');
  if (parts.length < 2) return null;
  try {
    var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (p.length % 4 != 0) {
      p += '=';
    }
    final payload = jsonDecode(utf8.decode(base64.decode(p)));
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}
