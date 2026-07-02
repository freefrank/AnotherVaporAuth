# Google Play Release Audit — AVA

Date: 2026-07-01 (original: Codex; reviewed & revised 2026-07-01: Claude)

Scope: Flutter Android app under `app/`, with focus on Google Play readiness, security-sensitive storage, privacy-policy consistency, permissions, and release build verification.

> Revision note (Claude): verified the original findings against the current
> code. Blockers #1 (debug signing) and #2 (weak at-rest KDF) are confirmed and
> stand. Blocker #3 was **downgraded**: the password-storage model has since been
> consolidated to the maFile, so the privacy policy is now *accurate* and this is
> no longer an implementation-vs-policy conflict — only leftover legacy code and a
> stale comment remain (see revised §3). Finding #2's framing was sharpened to
> explain why raising iterations is not the fix. Permission finding #4 stands.

## Executive Summary

The project is close to a releasable Android build from a technical build perspective: static analysis passes, the test suite passes, and a release App Bundle can be produced.

It is not ready for direct Google Play production upload yet. The two real blockers are (1) release signing and (2) the security posture of the at-rest encryption for locally stored Steam authenticator secrets. Privacy/data-safety wording is broadly accurate (the password-storage model has been settled as maFile-based); remaining privacy work is confined to permission wording and cleaning up leftover legacy password-migration code.

## Verification Performed

Commands run from `app/`:

```sh
flutter analyze
flutter test
flutter build appbundle --release
```

Results:

- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 51 tests passed.
- `flutter build appbundle --release`: passed.
- Generated artifact: `app/build/app/outputs/bundle/release/app-release.aab`.
- AAB size reported by Flutter: 76.8 MB; filesystem size: about 74 MB.

Build warning observed:

- `mobile_scanner` and `share_plus` apply Kotlin Gradle Plugin directly. Flutter reports this may fail in future Flutter versions unless those plugins migrate to Built-in Kotlin support.

## Release Blockers

### 1. Release Build Uses Debug Signing

File: `app/android/app/build.gradle.kts`

Current release config:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Impact:

- This is not suitable for Google Play distribution.
- Uploading debug-signed release artifacts is not acceptable for a production release process.
- The generated AAB should be treated as a build-validation artifact only.

Required action:

- Add a real release signing config.
- Prefer Play App Signing with an upload key.
- Keep keystore material outside git.
- Load signing values from `key.properties`, environment variables, or CI secrets.

Suggested acceptance criteria:

- `flutter build appbundle --release` produces an AAB signed with the intended upload key.
- Google Play Console accepts the artifact on an internal testing track.

### 2. Local Secret Encryption Is Too Weak for Play-Store Security Claims — RESOLVED (2026-07-01)

> Update: fixed. The at-rest scheme now uses a random 256-bit DEK with
> AES-256-GCM; the DEK is held in Android Keystore-backed storage, PIN-wrapped
> (`VaultCrypto`/`VaultKeyStore`, spec:
> `docs/superpowers/specs/2026-07-01-at-rest-encryption-dek-design.md`). The PIN
> no longer derives the file key, so copied maFiles are useless off-device and
> the 1e6 PIN space no longer bounds at-rest strength. Legacy stores migrate
> automatically on first unlock (crash-safe: new `.v2.maFile` files + atomic
> manifest flip). Verified on-device: migration, vault unlock, biometric, PIN
> change. The original finding is retained below for history.

File: `app/lib/src/services/account_store.dart`

Relevant code:

```dart
static const int avaIterations = 100;
```

The app stores Steam Guard secrets, identity secrets, revocation codes, access tokens, refresh tokens, and optionally Steam passwords. These are account-takeover-sensitive values.

Confirmed: `avaIterations = 100` (account_store.dart:262) is the PBKDF2 round count for AVA's own PIN encryption, and it is a deliberate choice — the code comment argues that because a 6-digit PIN has only ~1e6 combinations, high rounds add little and the "real protection is on-device storage + keystore-backed biometric."

That reasoning is half right, and the gap matters:

- The comment is correct that raising the iteration count is **not** the real fix. With a 1e6 PIN space, even 600k-round PBKDF2 only turns a seconds-long brute force into an hours-to-days one — still tractable for a motivated attacker who has the files. So do not "just bump iterations" and call it fixed.
- But the claimed mitigation does not actually hold in the current code path. The at-rest encryption key is **derived entirely from the PIN**; the Android Keystore is only used to stash the passkey for biometric convenience — it does **not** wrap the data-encryption key. So if biometric is not enrolled, or the attacker reads the maFiles directly (bypassing the app), the only barrier is 100-round PBKDF2 over a 1e6 space, which falls in seconds.

Required action:

- Rework Android secret storage before production release. This is the substantive fix, not the iteration count.
- Recommended design: generate a random high-entropy data-encryption key (DEK), wrap/store it with Android Keystore (TEE/StrongBox where available), and use the app PIN/device credential as an unlock **gate** rather than as the cryptographic root. Then the 1e6 PIN space no longer bounds the at-rest strength.
- Update the account_store.dart comment and the in-app/security text once the DEK model lands, so the documented rationale matches the real protection.

Suggested acceptance criteria:

- Extracted `maFiles/` alone are not practically decryptable with a quick offline 6-digit PIN brute force.
- The privacy policy and in-app security text accurately describe what protects the data at rest.

### 3. Legacy Password-Storage Code and a Stale Comment (downgraded — not a policy conflict) — comment fixed 2026-07-01

> Update: the misleading `CredentialStore` doc comment now describes its real
> role (legacy read-only migration source). The legacy keystore→maFile migration
> path remains until no old-format accounts exist. No policy change was needed.

Files:

- `app/lib/src/services/credential_store.dart`
- `app/lib/src/app/providers.dart`
- `app/lib/src/ui/login_screen.dart`
- `app/lib/src/core/models/steam_guard_account.dart`

Revision (Claude): the original audit flagged this as a privacy-policy-vs-implementation **conflict**. Re-reading the current code, there is no conflict — the model is settled and the privacy policy matches it:

- `SteamGuardAccount` has a `password` field that serializes into the maFile JSON (steam_guard_account.dart:26,71,124). This is the intended, current store, and the privacy policy correctly says the optional password lives in the maFile.
- `CredentialStore` (Android Keystore) is now **legacy, read-only migration source only**: `refreshSessions` does a one-time migration that moves any old keystore password *into* the maFile (providers.dart:214-223); `login_screen` reads the keystore only as a fallback for accounts saved by older builds (login_screen.dart:70); `removeAccount` clears the stale keystore entry (providers.dart:387). No current flow writes a new password to the keystore.

So the only real issues are housekeeping, not disclosure:

- `credential_store.dart`'s class doc comment still says passwords are "Kept OUT of the maFile," which is now misleading — it describes the old model, not the current one.
- The legacy migration/fallback path can be retired once enough time has passed that no old-format accounts remain.

Impact:

- Low. Play Console Data safety and the privacy policy should be prepared against the **maFile** model, which is what the policy already states. No wording change is required for accuracy here (permission wording is handled separately in §4).

Required action:

- Fix the stale `CredentialStore` doc comment to describe its real role (legacy migration source), or remove the class once migration is no longer needed.
- Keep the maFile as the single documented password-storage model across code comments, in-app text, privacy policy, and Play data-safety answers (already consistent).
- Note: the residual risk of a plaintext password inside an *exported* maFile is real, but it is an accepted, disclosed trade-off — tracked under Security Findings below, not here.

### 4. Final Release Manifest Has More Permissions Than Main Manifest Shows — privacy wording updated 2026-07-01

> Update: PRIVACY.md / PRIVACY_ZH.md now list network-state and
> fingerprint/biometric alongside Internet and Camera, and describe the new
> Keystore-DEK at-rest encryption. Play Console permission declarations should
> still be filled from the merged release manifest at submission time.

Source manifest: `app/android/app/src/main/AndroidManifest.xml`

Merged release manifest: `app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`

Merged release permissions observed:

- `android.permission.INTERNET`
- `android.permission.USE_BIOMETRIC`
- `android.permission.CAMERA`
- `android.permission.USE_FINGERPRINT`
- `android.permission.ACCESS_NETWORK_STATE`
- app-specific dynamic receiver permission from AndroidX

Impact:

- Google Play permission declarations and privacy-policy permission wording should be based on the merged release manifest, not only the source manifest.
- The current privacy policy mentions Internet, Camera, and Biometric/device credential, but not `ACCESS_NETWORK_STATE` or legacy `USE_FINGERPRINT`.

Required action:

- Update release checklist to audit the merged manifest before upload.
- Ensure Play Console permissions and privacy policy accurately describe all user-visible/sensitive permissions.

## Google Play Data Safety Notes

The app states it has no developer-operated backend and no analytics, telemetry, ads, crash reporting, or tracking. That is consistent with the code reviewed at a high level: no analytics SDKs or ad SDKs were observed.

Data handled locally includes:

- Steam account identifiers and account names.
- Steam Guard shared secret and identity secret.
- Revocation code.
- Device ID.
- Steam access and refresh tokens.
- Optional Steam password (stored in the account's maFile — model settled).
- Cached avatar/frame URLs and persona name.
- App settings and unlock material.
- In-memory debug log.

Data transmitted off-device:

- Direct HTTPS requests to Valve/Steam services.
- Steam content CDN requests for avatar/frame images.
- No AVA-operated server was identified.

Play Console answers should be prepared carefully. Even when the app does not collect data for the developer, it does transmit user data to a third party service selected by the app's function: Steam/Valve. The wording should distinguish "developer collection" from "data transmitted to Steam to provide app functionality".

## Security Findings

### High: Account-Takeover Secrets Are Exportable as Plain maFile — export warning added 2026-07-01

> Update: the export flow now shows an explicit confirmation dialog before a
> plaintext maFile leaves the app, with an extra line called out when the account
> has a saved Steam password. Encrypted export is still not offered (kept for SDA
> compatibility); the warning is the mitigation.

The app supports exporting unencrypted maFiles. This is an expected feature for SDA compatibility, but it is high risk.

Current privacy policy warns users that exported maFiles contain Steam Guard secrets and optional passwords. Keep this warning. Also ensure the in-app export flow presents a clear warning immediately before sharing/exporting.

Recommended action:

- Add or verify an explicit confirmation dialog before export.
- If saved passwords remain possible, warn specifically when a password is present.
- Prefer encrypted export as an option if compatibility requirements allow it.

### Medium: Password in maFile Is a Deliberate, Disclosed Trade-off

Revision (Claude): this was originally "High: needs reconsideration." The maFile password store is now the intended, user-facing design (opt-in save-password checkbox, disclosed in the privacy policy and the checkbox hint). It is not an accidental conflict. Storing the password in the maFile does increase blast radius — any unencrypted export or weak-PIN/local compromise exposes password and TOTP material together — but that is a chosen, disclosed trade-off, so it is Medium, not High.

Recommended action (defence-in-depth, not a blocker):

- The at-rest strength here rides entirely on the §2 fix — a Keystore-wrapped DEK is what actually protects the stored password on-device. Prioritise §2.
- Keep the save-password default reviewable; consider making it opt-in rather than on-by-default if reviewers push back.
- Do not include saved passwords in an export without an explicit, password-specific warning at export time (see the export finding below).

### Medium: Debug Log Can Contain Sensitive Operational Metadata

The debug log is in-memory only and appears not to log raw tokens directly. It does log account names, paths, URLs, item names, and network flow details.

Recommended action:

- Keep token redaction discipline strict.
- Before Play release, review every `dlog(...)` call for secrets, cookies, tokens, QR challenge URLs, device IDs, and account identifiers.
- Consider disabling the copy-all debug log in production builds or gating it behind an advanced setting.

### Medium: Network Protocol Flows Require Live Validation

The README notes that some Steam network flows require live credential validation. That remains important for production readiness.

Recommended action:

- Run internal testing with real test Steam accounts.
- Validate password login, QR login, QR approve, authenticator linking, confirmations, market listing, session refresh, and passwordless/no-password paths.

## Android Packaging Findings

Package/build info from merged release manifest:

- Package/application ID: `pro.dotslash.ava`
- Version code: `1`
- Version name: `0.63.1`
- Minimum SDK: `24`
- Target SDK: `36`

Notes:

- `versionCode=1` is valid for the first Play upload. Every subsequent upload must increment it.
- Application ID should be treated as permanent once released on Play.
- Android namespace and application ID are both `pro.dotslash.ava` (renamed 2026-07-02, pre-first-upload).

## Policy and Store Listing Checklist

Before submitting to Google Play:

- Publish a stable privacy policy URL accessible without authentication.
- Ensure `PRIVACY.md` and `PRIVACY_ZH.md` match actual app behavior.
- Mention direct Steam/Valve communication clearly.
- Mention all permissions from the merged release manifest.
- State that the app is not affiliated with Valve or Steam in the Play listing.
- Avoid implying endorsement by Steam or Valve.
- Prepare data-safety answers for locally stored secrets and Steam-bound network transmission.
- Prepare tester instructions for the internal test track.
- Prepare screenshots showing the actual app, not only marketing material.

## Recommended Remediation Order

1. Add production release signing. (Blocker §1 — DONE: wired from key.properties.)
2. ~~Rework local secret encryption: Keystore-wrapped random DEK.~~ (Blocker §2 — DONE 2026-07-01; verified on-device.)
3. Housekeeping: fix the stale `CredentialStore` comment and retire the legacy keystore→maFile migration path when no longer needed. (§3 — low priority; password-storage model is already settled as maFile.)
4. Inspect the merged release manifest (§4) and align Play Console permission declarations + privacy-policy permission wording (add ACCESS_NETWORK_STATE, USE_FINGERPRINT). Password-storage wording already matches the maFile model.
5. Add/confirm an explicit export warning, called out specifically when a saved password is present.
6. Re-run `flutter analyze`, `flutter test`, and `flutter build appbundle --release` with the real signing config.
7. Upload to Google Play internal testing track.
8. Run live Steam integration tests with test accounts (password login, QR login/approve, linking, confirmations, market listing, session refresh, no-password paths).
9. Promote only after the internal track install and core flows pass.

## Current Go / No-Go

No-go for production release.

Go for internal technical validation after release signing is fixed.

