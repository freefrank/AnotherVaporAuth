# Full-Stack Security & Quality Audit - AVA / SteamDesktopAuthenticator

Date: 2026-07-04
Mode: read-only audit; no files modified.
Scope: Flutter app, Steam protocol clients, local vault/storage, Android build config, Cloudflare feedback worker/static site, CI, dependency/config hygiene.

## Executive Summary

The codebase shows unusually strong security work for a small authenticator app: vault encryption is designed around a random DEK, Steam-origin redirect handling has been hardened, path traversal is addressed, writes are mostly crash-safe, debug logs are redacted, privacy gating exists before first network activity, and there is meaningful unit coverage.

The largest remaining risks are operational and threat-model boundary issues rather than obvious code bugs:

1. A real-looking Android signing `key.properties` exists in the local workspace.
2. Release builds silently fall back to debug signing when signing config is absent.
3. Biometric unlock stores the app PIN/passkey in secure storage after a separate `local_auth` prompt, rather than using an authentication-bound keystore key.
4. Optional Steam password storage is enabled by default and travels inside exported plaintext maFiles.
5. Feedback relay abuse controls are soft/fail-open and should be complemented by edge rate limiting.

I did not run `flutter test`, `flutter analyze`, or build commands because they may write generated files and the request was read-only.

## High-Priority Findings

### 1. Local signing secret material is present in the workspace

Observed file:

- `app/android/key.properties`

It contains values for:

- `storePassword`
- `keyPassword`
- `keyAlias`
- `storeFile`

`git status --ignored` shows it is ignored, not tracked, which is good. But the file is still present in the working tree and appears to contain real upload-key credentials.

**Risk:** If this workspace is copied, uploaded, backed up insecurely, included in diagnostics, or exposed through a local compromise, the Android upload key password is leaked.

**Recommendation:**

- Treat this credential as sensitive.
- Move signing secrets outside the repository tree.
- Prefer CI/store secrets or environment variables.
- If this workspace has ever been shared, consider rotating the Play upload key.
- Ensure `dist/` artifacts were not produced with leaked credentials if they are distributed.

### 2. Release builds fall back to debug signing

File:

- `app/android/app/build.gradle.kts`

Current behavior: if `android/key.properties` is absent, the `release` build type uses the debug signing config.

**Risk:** A release artifact can be generated successfully but signed with the debug key. That is dangerous for release automation because missing secrets should fail closed, not silently produce a non-production artifact.

**Recommendation:**

- Make Play/release builds fail when release signing is missing.
- Keep debug fallback only for an explicitly named local/dev build variant, if needed.
- Add CI checks that verify the release AAB/APK is signed with the expected upload certificate.

### 3. Biometric unlock is not cryptographically bound to authentication

File:

- `app/lib/src/services/biometric_unlock.dart`

The flow authenticates with `local_auth`, then reads/writes the PIN/passkey from `flutter_secure_storage`.

**Risk:** The authentication prompt and secret retrieval are separate operations. This is user-friendly, but weaker than an Android Keystore key requiring user authentication for each unwrap/use. Runtime tampering, rooted devices, or app-process compromise can potentially bypass the local_auth gate and read the stored passkey through the app's own code path.

**Recommendation:**

- If supported by the storage stack, store/unwrap the vault key with a Keystore key configured with `userAuthenticationRequired`.
- Prefer storing an auth-bound DEK wrap over storing the PIN/passkey itself.
- Document current biometric unlock as a convenience feature, not as a stronger cryptographic boundary than the vault PIN.

## Medium-Priority Findings

### 4. Steam password storage is enabled by default and exported in maFiles

Relevant files:

- `app/lib/src/ui/login_screen.dart`
- `app/lib/src/core/models/steam_guard_account.dart`
- `app/lib/src/ui/import_helper.dart`

The optional Steam password is saved into the account model/maFile when enabled. The login screen defaults `_savePassword = true`. Export warns users, but exported maFiles are plaintext and include the password if present.

**Risk:** A plaintext exported maFile can become a full account-takeover bundle: shared secret, identity secret, refresh/access tokens, revocation code, and possibly Steam password.

**Recommendation:**

- Consider defaulting saved-password storage to off.
- Keep auto-login as an explicit opt-in with stronger wording.
- Consider storing the password separately in platform credential storage instead of serializing it into exported maFiles, or strip it by default during export with an explicit "include password" option.

### 5. Feedback worker abuse control is best-effort and fail-open

Relevant files:

- `infra/feedback-worker/src/index.js`
- `infra/feedback-worker/wrangler.toml`

The worker has size caps and KV-backed per-IP rate limits, which is good. However, the client token is public by design, KV increments are non-atomic, and rate-limit storage errors fail open.

**Risk:** A scripted attacker can still use the public relay to generate unwanted email traffic, especially during KV issues or distributed/burst traffic.

**Recommendation:**

- Add Cloudflare WAF/rate-limiting rules at the custom domain.
- Consider failing closed on repeated KV errors if abuse starts.
- Check `Content-Length` before `request.json()` where available.
- Add worker tests for malformed JSON, oversized fields, rate-limit behavior, and SMTP failure responses.

### 6. PIN/KDF design relies heavily on device-keystore assumptions

Relevant files:

- `app/lib/src/core/crypto/vault_crypto.dart`
- `app/lib/src/services/vault_key_store.dart`

The vault uses a random DEK with AES-GCM, which is strong. The PIN-derived wrap uses PBKDF2 with `pinKdfIterations = 1`, relying on the Keystore-backed secure storage boundary.

**Risk:** This is acceptable if the threat model is "off-device copies of maFiles are useless." It is weaker against rooted-device/app-data extraction scenarios where secure-storage records and app code can be exercised locally.

**Recommendation:**

- Keep documenting this clearly.
- Consider optional longer alphanumeric passphrases for users who want export/copy-resistant security beyond a 6-digit PIN.
- Prefer auth-bound Keystore wrapping where platform APIs allow it.

## Low-Priority / Quality Findings

### 7. Some dependencies appear unused

`pubspec.yaml` includes packages that did not appear in `app/lib` or `app/test` imports during the audit:

- `cookie_jar`
- `dio_cookie_manager`
- `asn1lib`
- possibly `cupertino_icons`

**Recommendation:** Remove unused dependencies to reduce supply-chain surface and maintenance noise.

### 8. Generated/build artifacts are present locally

Observed ignored workspace directories/files include:

- `app/.dart_tool/`
- `app/build/`
- `dist/`
- `infra/feedback-worker/node_modules/`

They are ignored, not tracked, which is good.

**Recommendation:** Keep these out of commits and release source bundles. Consider a clean-room release checklist that starts from a fresh checkout.

### 9. CI does not verify release signing or worker behavior

CI currently runs Flutter analyze/test. It does not appear to:

- build a release AAB with production-like signing checks,
- verify merged Android manifest permissions,
- run feedback-worker tests,
- audit npm/Dart dependencies.

**Recommendation:**

- Add a release-signing validation job.
- Add a merged-manifest permission diff/check.
- Add basic worker unit tests.
- Add scheduled dependency audit/update checks.

## Positive Security Observations

- Vault storage uses AES-256-GCM with a random DEK.
- Manifest path traversal is mitigated through filename sanitization.
- File writes use atomic temp-file rename patterns.
- Steam community redirect handling includes Steam-origin allowlisting.
- Image cache restricts downloads to Steam CDN hosts and caps size.
- Debug logs are redacted before storage/display.
- First-run privacy acceptance gates network startup.
- Android backup is disabled, matching the Keystore-bound vault model.
- Plaintext maFile export includes a warning and temp-file cleanup.
- Feedback worker sanitizes control characters and avoids leaking internal errors.

## Suggested Next Actions

1. Move/rotate local Android signing credentials as needed.
2. Make release signing fail closed when secrets are absent.
3. Rework biometric unlock toward authentication-bound Keystore use.
4. Reconsider default saved-password behavior.
5. Add Cloudflare edge rate limiting for the feedback worker.
6. Add CI checks for release signing, merged-manifest permissions, worker tests, and dependency hygiene.
