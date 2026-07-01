# At-Rest Encryption Rework — Keystore-Held DEK (§2)

Date: 2026-07-01
Status: proposed (awaiting review)
Related: `AUDIT.md` §2 (weak at-rest KDF), Google Play production readiness.

## Problem

AVA's internal `maFiles/` are encrypted with
`AES-256-CBC(key = PBKDF2-SHA1(PIN, salt, 100 rounds))`. The PIN is 6 digits
(~1e6 combinations), so anyone who copies the files can brute-force the PIN and
decrypt in seconds. The Android Keystore is currently used only to stash the
plaintext PIN for biometric convenience — it does **not** protect the data. If
biometric is off, or the files are extracted, the 100-round PIN KDF is the only
barrier.

## Goal

Make copied `maFiles/` cryptographically useless off the originating device, so
the 1e6 PIN space no longer bounds at-rest strength — while keeping unlock UX
(6-digit PIN, optional biometric) unchanged and keeping exported maFiles in the
SDA/.NET/ASF-compatible legacy format.

## Chosen model — Design A (Keystore-held DEK, PIN as gate)

- Generate a random 256-bit **Data Encryption Key (DEK)** once, per install.
- AVA's internal maFiles are encrypted with the DEK using **AES-256-GCM**
  (authenticated; per-file random 12-byte nonce).
- The DEK is protected by the Android Keystore, not by the PIN space:
  - **PIN path:** store `wrappedDEK = AES-GCM(KEK_pin, DEK)` where
    `KEK_pin = PBKDF2-SHA256(PIN, pinSalt, 100_000)`, inside
    `flutter_secure_storage` (Keystore master-key backed). Because the blob
    itself lives behind the Keystore master key, it can't be read off-device,
    so brute-forcing the PIN offline is impossible; the KDF rounds only bind the
    PIN. The GCM tag doubles as PIN verification (no separate check token).
  - **Biometric path (optional, unchanged UX):** store the raw DEK in a second
    `flutter_secure_storage` entry, gated by the existing `BiometricUnlock`
    device-auth prompt. Biometric unlock returns the DEK directly.
- The PIN no longer derives the file-encryption key. It gates entry to the app
  and cryptographically binds the wrappedDEK, but the DEK's strength comes from
  being random + Keystore-resident, not from the PIN.

### Why this beats a pure UI-gate PIN

Binding the PIN into `wrappedDEK` (rather than a plain equality check on a stored
PIN) means the PIN is still cryptographically required to recover the DEK on the
PIN path — no usability cost, strictly stronger than comparing a stored PIN.

### Security properties

- Copied `maFiles/` + copied `flutter_secure_storage` blobs, moved to another
  device: undecryptable (Keystore master key is non-exportable, hardware-bound).
- On-device attacker without PIN/biometric: cannot complete the biometric prompt
  and cannot derive `KEK_pin`; the wrappedDEK GCM tag fails on wrong PINs.
- Residual (accepted, documented): an attacker running code **as the app's uid
  on the unlocked device** can read the DEK from secure storage. True of any
  local scheme; out of scope.

## Scope boundary — export/import stays legacy

The DEK scheme is **internal only**. Import/export keep the SDA-compatible
format so ASF/.NET and other SDA tools still interoperate:

- **Export:** decrypt the internal maFile with the DEK → emit a plaintext (or
  legacy PBKDF2-SHA1/AES-CBC) SDA maFile. Unchanged externally.
- **Import:** parse the SDA maFile → re-encrypt internally under the DEK.

`MaFileCrypto` (legacy CBC/SHA1) is retained unchanged for this boundary and for
the one-time migration read. A new `VaultCrypto` module handles DEK/GCM.

## Components

- **`VaultCrypto`** (new, `lib/src/core/crypto/vault_crypto.dart`)
  - `generateDek() -> Uint8List` (32 random bytes).
  - `wrapDek(pin, pinSaltB64, dek) -> String` / `unwrapDek(pin, pinSaltB64, blob) -> Uint8List?`
    (AES-GCM over the DEK, PBKDF2-SHA256 100k KEK; null on wrong PIN).
  - `encryptPayload(dek, plaintext) -> String` / `decryptPayload(dek, blob) -> String?`
    (AES-256-GCM, nonce prepended; base64 out).
  - Pure Dart (pointycastle `GCMBlockCipher`), unit-testable, no platform deps.
- **`VaultKeyStore`** (new, `lib/src/services/vault_key_store.dart`)
  - Wraps `flutter_secure_storage`: read/write the wrappedDEK blob + pinSalt, and
    the biometric raw-DEK entry. Keys: `ava.vault.wrappedDek`, `ava.vault.pinSalt`,
    `ava.vault.bioDek`.
- **`AccountStore`** (changed): a `vault` (DEK) mode alongside the legacy CBC
  path. When `manifest.vault == true`, `saveAccount`/`getAllAccounts` use
  `VaultCrypto` with the in-memory DEK instead of PBKDF2/CBC. Per-file
  `ManifestEntry` stores the GCM nonce (reuse `iv`), no `salt`/rounds.
- **`Manifest`** (changed): add `vault: bool` (default false) and a
  `schemaVersion: int` (default 1; vault stores write 2). Legacy fields remain
  for back-compat parsing.
- **`AppController`/providers** (changed): unlock returns the DEK (from PIN
  unwrap or biometric); it's held in memory in place of `passKey`. `BiometricUnlock`
  stores the DEK, not the PIN.

## Migration (one-time, at first unlock after update)

Runs right after a successful legacy unlock, when accounts are already decrypted
in memory (mirrors the existing `reencrypt()` path):

1. Detect legacy store: `manifest.vault != true`.
2. `dek = generateDek()`; `pinSalt = random`; write
   `wrappedDek = wrapDek(PIN, pinSalt, dek)` + `pinSalt` to `VaultKeyStore`.
3. Re-encrypt every account: write each `<steamId>.maFile` as
   `encryptPayload(dek, accountJson)`; update each `ManifestEntry` (new nonce,
   clear legacy salt/rounds).
4. Set `manifest.vault = true`, `schemaVersion = 2`, drop `kdfIterations`/
   `passkeyCheck`; `save()`.
5. If biometric was enabled, re-store the DEK behind biometric.
6. Ordering for crash-safety: write all new maFiles first, then flip the manifest
   last (the manifest is the source of truth for which scheme to read). If the
   process dies mid-migration, the manifest still says legacy and files are
   re-derivable on next unlock. Old maFiles are overwritten in place by steamId,
   so no orphan cleanup needed.

## Lockout & recovery

- The DEK lives only in Keystore-backed storage. If it is lost, the internal
  store is unrecoverable. Loss vectors and mitigations:
  - **Biometric enrollment change:** do **not** set
    `invalidatedByBiometricEnrollment` on the wrappedDEK/pinSalt entries, so
    re-enrolling a fingerprint does not destroy them. Only the optional
    `bioDek` fast-path entry may be invalidated — harmless, PIN path still works.
  - **App data cleared / uninstall:** takes the `maFiles/` with it anyway.
- Primary recovery is a previously **exported maFile** (plaintext or legacy).
  After migration completes, show a one-time prompt nudging the user to export a
  backup. Export remains available any time from the account menu.

## Testing (TDD)

- `VaultCrypto`: GCM round-trip; wrong-PIN unwrap returns null; tampered
  ciphertext/tag rejected; wrap/unwrap round-trip; nonce uniqueness.
- `AccountStore` vault mode: save→getAll round-trip; wrong DEK returns empty;
  legacy→vault migration produces readable vault files and a version-2 manifest.
- Migration idempotency: re-running after a completed migration is a no-op.
- Export still emits a legacy/plaintext maFile that `MaFileCrypto` (and the old
  format) can read; import of a legacy maFile lands as a vault file.
- Existing 51 tests stay green (legacy `MaFileCrypto` untouched).

## Out of scope

- Changing the exported maFile format (stays SDA-compatible).
- Cloud sync / cross-device key escrow (future; the DEK model doesn't preclude
  a later PIN-wrapped export-for-sync).
- Rooted-device in-app DEK extraction.

## Rollout

Ship behind the normal update; migration is automatic and transparent on first
unlock. No user action required beyond the optional backup nudge. Bump version
and note the at-rest encryption upgrade in CHANGELOG.
