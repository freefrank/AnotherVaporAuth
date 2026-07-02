import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart' as hashlib;
import 'package:pointycastle/export.dart';

/// AVA's internal at-rest encryption for the `maFiles/` vault.
///
/// Unlike [MaFileCrypto] (which is byte-compatible with the legacy SDA/.NET
/// format and used only at the import/export boundary), this scheme is
/// AVA-internal and can evolve freely. It uses a random 256-bit Data Encryption
/// Key (DEK) with AES-256-GCM (authenticated). The DEK is never derived from the
/// PIN; it is generated randomly and kept in Android Keystore-backed storage.
/// The PIN only *wraps* the DEK ([wrapDek]) as a binding gate.
///
/// Blob layout for every ciphertext (base64 encoded):
///   nonce(12) || ciphertext || tag(16)
class VaultCrypto {
  static const int dekLength = 32; // AES-256
  static const int nonceLength = 12; // GCM standard nonce
  static const int macSizeBits = 128; // 16-byte tag
  static const int pinSaltLength = 16;

  /// PBKDF2-SHA256 rounds for the PIN-derived key-encryption key — the RFC
  /// minimum, on purpose. A 6-digit PIN has only 10^6 candidates, so no
  /// feasible round count survives an offline attack (one GPU clears the whole
  /// space at 100k rounds in ~20s); iterations buy nothing but unlock latency.
  /// The real barrier is the Keystore master key: off-device the wrapped DEK
  /// is unreadable regardless of the PIN. The KDF's only job is to map the PIN
  /// onto a 256-bit key. The count is recorded per-wrap ([VaultKeyStore]), so
  /// old wraps keep opening and get re-wrapped on their next unlock.
  static const int pinKdfIterations = 1;

  static final Random _rng = Random.secure();

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  /// A fresh random 256-bit DEK.
  static Uint8List generateDek() => _randomBytes(dekLength);

  /// A fresh random 16-byte salt, base64 encoded (for [wrapDek]).
  static String randomSaltB64() => base64.encode(_randomBytes(pinSaltLength));

  /// Derives the PIN key-encryption key with PBKDF2-HMAC-SHA256.
  ///
  /// Uses hashlib rather than pointycastle: identical output (verified against
  /// each other and a fixture in the tests), ~4.5x faster — still relevant for
  /// pre-migration wraps that were written at 100k rounds.
  static Uint8List _deriveKek(String pin, String saltB64, int iterations) {
    if (pin.isEmpty) throw ArgumentError('PIN is empty');
    final salt = base64.decode(saltB64);
    return Uint8List.fromList(
        hashlib.pbkdf2(utf8.encode(pin), salt, iterations, dekLength).bytes);
  }

  /// AES-256-GCM encrypt [plain] under [key]; returns nonce||ct||tag (base64).
  static String _seal(Uint8List key, Uint8List plain) {
    final nonce = _randomBytes(nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), macSizeBits, nonce,
          Uint8List(0)));
    final ct = cipher.process(plain);
    final out = Uint8List(nonce.length + ct.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, nonce.length + ct.length, ct);
    return base64.encode(out);
  }

  /// Inverse of [_seal]; returns null on a wrong key or tampered data.
  static Uint8List? _open(Uint8List key, String blobB64) {
    try {
      final raw = base64.decode(blobB64);
      if (raw.length < nonceLength + (macSizeBits ~/ 8)) return null;
      final nonce = raw.sublist(0, nonceLength);
      final ct = raw.sublist(nonceLength);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), macSizeBits, nonce,
            Uint8List(0)));
      return cipher.process(Uint8List.fromList(ct));
    } catch (_) {
      return null; // InvalidCipherTextException (bad tag) or malformed input
    }
  }

  /// Wraps [dek] with a PIN-derived key. Returns a base64 blob to store in
  /// Keystore-backed secure storage.
  static String wrapDek(String pin, String pinSaltB64, Uint8List dek,
      {int iterations = pinKdfIterations}) {
    final kek = _deriveKek(pin, pinSaltB64, iterations);
    return _seal(kek, Uint8List.fromList(dek));
  }

  /// Unwraps a blob produced by [wrapDek]. Returns null on a wrong PIN, wrong
  /// salt, or tampering.
  static Uint8List? unwrapDek(String pin, String pinSaltB64, String blobB64,
      {int iterations = pinKdfIterations}) {
    final kek = _deriveKek(pin, pinSaltB64, iterations);
    return _open(kek, blobB64);
  }

  /// Encrypts a maFile payload string with the raw [dek]. Returns base64.
  static String encryptPayload(Uint8List dek, String plaintext) =>
      _seal(Uint8List.fromList(dek),
          Uint8List.fromList(utf8.encode(plaintext)));

  /// Decrypts a payload produced by [encryptPayload]; null on wrong DEK/tamper.
  static String? decryptPayload(Uint8List dek, String blobB64) {
    final plain = _open(Uint8List.fromList(dek), blobB64);
    if (plain == null) return null;
    try {
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }
}
