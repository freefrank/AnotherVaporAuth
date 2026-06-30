import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypts and decrypts `*.maFile` payloads, byte-for-byte compatible with the
/// legacy C# `FileEncryptor` (Steam Desktop Authenticator .NET).
///
/// Scheme (must not change — existing user files depend on it):
///   key = PBKDF2(password, salt, 50000 rounds, HMAC-SHA1) -> 32 bytes
///   cipher = AES-256-CBC, PKCS7 padding
///   salt: 8 random bytes, base64
///   iv:   16 random bytes, base64
///   output: base64(ciphertext)
class MaFileCrypto {
  static const int pbkdf2Iterations = 50000;
  static const int saltLength = 8;
  static const int keySizeBytes = 32;
  static const int ivLength = 16;

  static final Random _rng = Random.secure();

  /// 8-byte cryptographically random salt, base64 encoded.
  static String getRandomSalt() => base64.encode(_randomBytes(saltLength));

  /// 16-byte cryptographically random IV, base64 encoded.
  static String getInitializationVector() =>
      base64.encode(_randomBytes(ivLength));

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  /// PBKDF2-HMAC-SHA1 key derivation. Exposed for cross-implementation tests
  /// (RFC 6070 vectors). Defaults match the maFile scheme (50000 rounds, 32B).
  static Uint8List deriveKey(
    String password,
    String saltB64, {
    int iterations = pbkdf2Iterations,
    int dkLen = keySizeBytes,
  }) {
    if (password.isEmpty) throw ArgumentError('Password is empty');
    if (saltB64.isEmpty) throw ArgumentError('Salt is empty');
    final salt = base64.decode(saltB64);
    final derivator = PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, dkLen));
    return derivator.process(
      Uint8List.fromList(utf8.encode(password)),
    );
  }

  /// Decrypts a base64 ciphertext. Returns `null` on a wrong key / bad padding,
  /// mirroring the C# behaviour of returning null instead of throwing.
  static String? decrypt(
    String password,
    String saltB64,
    String ivB64,
    String encryptedB64, {
    int iterations = pbkdf2Iterations,
  }) {
    if (password.isEmpty || saltB64.isEmpty || ivB64.isEmpty ||
        encryptedB64.isEmpty) {
      throw ArgumentError('Empty argument to decrypt');
    }
    try {
      final key = deriveKey(password, saltB64, iterations: iterations);
      final iv = base64.decode(ivB64);
      final cipherText = base64.decode(encryptedB64);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      )..init(
          false,
          PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
            ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
            null,
          ),
        );
      final plain = cipher.process(cipherText);
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }

  /// Encrypts plaintext and returns base64 ciphertext.
  static String encrypt(
    String password,
    String saltB64,
    String ivB64,
    String plaintext, {
    int iterations = pbkdf2Iterations,
  }) {
    if (password.isEmpty || saltB64.isEmpty || ivB64.isEmpty ||
        plaintext.isEmpty) {
      throw ArgumentError('Empty argument to encrypt');
    }
    final key = deriveKey(password, saltB64, iterations: iterations);
    final iv = base64.decode(ivB64);
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        true,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    final cipherText = cipher.process(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    return base64.encode(cipherText);
  }

  /// Decrypts several payloads in a background isolate so the expensive PBKDF2
  /// derivations don't block the UI thread. Each item is `(salt, iv, ciphertext)`
  /// and maps to its plaintext (or null on a wrong key).
  static Future<List<String?>> decryptBatch(
    String password,
    List<(String, String, String)> items, {
    int iterations = pbkdf2Iterations,
  }) {
    if (items.isEmpty) return Future.value(const []);
    return Isolate.run(() => [
          for (final (salt, iv, ct) in items)
            (salt.isEmpty || iv.isEmpty || ct.isEmpty)
                ? null
                : decrypt(password, salt, iv, ct, iterations: iterations),
        ]);
  }
}
