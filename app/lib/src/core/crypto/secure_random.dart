import 'dart:math';
import 'dart:typed_data';

/// The one process-wide CSPRNG. Shared by every caller that needs
/// cryptographic randomness (vault DEK/nonce, maFile salt/IV, community
/// session ids) instead of each file holding its own `Random.secure()`.
final Random _rng = Random.secure();

/// [n] cryptographically random bytes.
Uint8List secureRandomBytes(int n) {
  final b = Uint8List(n);
  for (var i = 0; i < n; i++) {
    b[i] = _rng.nextInt(256);
  }
  return b;
}

/// [chars] random lowercase hex characters (4 bits of entropy each).
String secureRandomHex(int chars) {
  const hex = '0123456789abcdef';
  final bytes = secureRandomBytes(chars);
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(hex[b & 0x0F]);
  }
  return buf.toString();
}
