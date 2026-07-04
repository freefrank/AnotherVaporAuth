# Adversarial Code Audit - 2026-07-03

Scope: Flutter/Dart app under `app/`, Steam protocol clients, local account storage, import/export paths, debug logging, and the feedback worker under `infra/feedback-worker`.

This audit intentionally focuses on hostile inputs, crash consistency, secret handling, and "malignant" bugs that can cause account lockout, account compromise, or data loss.

> **Resolution (2026-07-03, v0.74.4):** all six findings addressed, each with a
> regression test where unit-testable.
> - High cross-origin cookie leak → `isSteamOrigin` allowlist gates redirect hops (`07d12a5`).
> - High finalize retry timing → wait for a fresh TOTP window between retries (`6694d7c`).
> - Medium manifest path traversal → `StorageProvider.sanitizeFilename` choke point (`0c58bee`).
> - Medium non-atomic writes → temp-file+rename, payload-before-manifest ordering (`4d1a470`).
> - Medium feedback-worker error leak / injection → generic errors + control-char sanitize (`df31b1b`).
> - Low debug-log secrets → `DebugLog.redactSecrets` before every line (`729cd93`).
>
> Remaining operational task (not code): WAF rate-limiting on the feedback
> worker's custom domain, and deploying the worker change with `wrangler deploy`.
>
> **Second pass (v0.75.1):** a follow-up review surfaced seven more findings,
> all fixed with regression tests —
> - #1 legacy encrypted update crash window → fresh-file two-phase commit (`3af175d`).
> - #2 non-transactional `changeEncryptionKey` → write all payloads, then one atomic manifest commit (`3af175d`).
> - #3 `resetVault` could half-brick → commit a clean manifest before dropping keys (`7ca5f65`).
> - #4 initial community URL not origin-gated → gate absolute initial URLs (`86347f5`).
> - #5 `QrChallenge.tryParse` accepted any host → Steam-host + https allowlist (`a6253b2`).
> - #6 one corrupt blob blanked the whole list → keep decodable accounts (`3af175d`).
> - #7 market auto-confirm over-approved → confirm only newly-created listings (`0e7c14f`).

## Verification

Commands run from `app/`:

```sh
flutter test
flutter analyze
```

Results:

- `flutter test`: passed, 98 tests passed.
- `flutter analyze`: passed, no issues found.

Not treated as findings in this document because they are explicit product decisions:

- The 6-digit PIN / low PBKDF2 cost design for the vault DEK wrap.
- Saving the optional Steam password in the maFile, including the plaintext-export warning model.

## Executive Summary

The codebase has strong unit coverage around crypto primitives, model round trips, account-store migration, and skin parsing. Static analysis is clean.

The main remaining risks are not analyzer-detectable. They sit in protocol edge cases and file-system consistency:

- Steam cookies can be carried across a manually followed cross-origin redirect.
- Authenticator finalization can spin through repeated TOTP submissions without waiting for the next 30-second code window.
- Local manifest filenames are trusted and can escape the `maFiles` directory if the manifest is tampered with.
- Several account-store writes are not atomic across manifest and payload files, so a crash can leave the vault internally inconsistent.
- The feedback worker is intentionally public but lacks real abuse controls and returns internal error details.

## Findings

### High: Cross-Origin Redirect Can Leak Steam Session Cookies

Files:

- `app/lib/src/services/steam_api_client.dart`
- `app/lib/src/core/protocol/inventory_client.dart`

Relevant code:

- `SteamApiClient.communityGetText` accumulates cookies and sends them on every redirect hop.
- Redirect handling accepts absolute URLs:

```dart
url = loc.startsWith('http') ? loc : '$communityBase$loc';
resp = await _dio.get<String>(url, options: opts());
```

`InventoryClient.overview` calls this path with a `steamLoginSecure` cookie.

Impact:

If Steam, a compromised intermediary endpoint, or a future caller produces a redirect to a non-Steam absolute URL, the app will continue sending the current `Cookie` header to that external origin. That cookie includes `steamLoginSecure`, which is account-session material.

Why this is adversarially important:

- The code manually implements redirect following because `followRedirects` is disabled globally.
- The cookie jar is local to the method and does not enforce domain scoping.
- The redirect target is treated as a string, not as a parsed URI with an allowlist.

Recommended fix:

- Parse the redirect target with `Uri`.
- Allow only `https://steamcommunity.com` for community HTML flows unless a specific Steam-owned host is required.
- On any origin change, either stop following the redirect or clear auth cookies before the next request.
- Reject non-HTTPS redirect targets.

Suggested tests:

- Fake a 302 from `/profiles/<id>/inventory/` to `https://evil.example/x` and assert no request is made with `steamLoginSecure`.
- Fake a relative Steam redirect and assert cookies are preserved.

### High: Authenticator Finalize Retries Same TOTP Window Repeatedly

File: `app/lib/src/core/protocol/authenticator_linker.dart`

Relevant code:

```dart
while (tries <= 30) {
  final time = SteamTime.currentSteamTime;
  final code = account.generateCode(time);
  ...
  if (wantMore || status == 88) {
    tries++;
    continue;
  }
}
```

Impact:

When Steam returns `want_more` or status `88`, the code immediately retries. Because Steam Guard codes are stable for 30 seconds, most or all retries can submit the same code. This can cause authenticator finalization to fail, trigger rate limits, or leave the account in a partially linked state that requires recovery.

Recommended fix:

- After `want_more` or status `88`, wait until the next TOTP window before retrying.
- Use `SteamTotp.secondsRemaining(time)` plus a small buffer.
- Consider capping retries by elapsed time rather than a tight loop count.

Suggested tests:

- Inject a fake time source into `AuthenticatorLinker`.
- Simulate two `want_more` responses and assert the second request uses a later 30-second TOTP window.
- Assert no tight retry loop occurs when Steam keeps returning `want_more`.

### Medium: Manifest Filenames Are Trusted and Can Escape `maFiles`

Files:

- `app/lib/src/core/models/manifest.dart`
- `app/lib/src/services/storage_provider.dart`
- `app/lib/src/services/account_store.dart`

Relevant code:

```dart
filename: (json['filename'] ?? '') as String
```

```dart
Future<String> filePath(String filename) async =>
    p.join(await maFilesDir(), filename);
```

Impact:

A tampered `manifest.json` can include filenames such as `../somewhere_else` or an absolute path. Those filenames are later used for reads, writes, and deletes. On desktop especially, where `maFiles` lives next to the executable, this creates a path-traversal risk against local files reachable by the process.

Recommended fix:

- Treat manifest filenames as untrusted.
- Accept only a basename matching a strict pattern, for example Steam ID filenames and `.v2.maFile`.
- Reject absolute paths, `..`, path separators, empty names, and names not ending in `.maFile`.
- In `StorageProvider.filePath`, normalize and verify that the result remains inside `maFilesDir`.

Suggested tests:

- Loading a manifest with `../x.maFile` should throw a manifest validation error.
- Removing an account must not delete any path outside `maFilesDir`.

### Medium: Account Store Writes Are Not Crash-Atomic

Files:

- `app/lib/src/services/account_store.dart`
- `app/lib/src/services/storage_provider.dart`

Relevant code:

```dart
await save();
await storage.writeFile(filename, jsonAccount);
```

`changeEncryptionKey` rewrites account files in a loop and saves the manifest after file writes.

Impact:

A crash, process kill, disk error, or partial write can leave `manifest.json` and the account payload files out of sync. Examples:

- Manifest points at new salt/IV or filename, but payload write did not complete.
- Some accounts are re-encrypted while others remain old-format.
- `getAllAccounts` returns an empty list if one vault payload decrypts to `null`, which can make a partial corruption look like all accounts disappeared.

Recommended fix:

- Add atomic file writes in `StorageProvider`: write to a temp file in the same directory, flush, then rename.
- For account updates, write the payload first under a temp/new filename, then atomically update the manifest.
- For bulk re-encryption, use a two-phase scheme: write all new payloads, then commit manifest once.
- On read, distinguish "wrong key" from "one corrupted account"; preserve recoverable accounts and surface a corruption warning.

Suggested tests:

- Simulate a crash after manifest write but before payload write.
- Simulate a crash after one file is re-encrypted during key rotation.
- Assert one corrupted account does not hide all other valid accounts.

### Medium: Feedback Worker Has No Strong Abuse Control and Leaks Internal Errors

Files:

- `infra/feedback-worker/src/index.js`
- `infra/feedback-worker/wrangler.toml`

Relevant code:

```js
const CLIENT_TOKEN = "ava-feedback-v1";
```

```js
return bad(500, `internal: ${e.message}`);
...
return bad(502, `send failed: ${e.message}`);
```

Impact:

The client token is public by design because it ships with the open-source app. Size caps help, but they do not prevent scripted abuse of the email relay. Returning internal exception text can expose SMTP/provider details and make abuse easier to tune.

Recommended fix:

- Add Cloudflare WAF/rate limiting for the custom domain.
- Consider Turnstile, per-install proof-of-work, or a server-side rolling token if spam becomes a problem.
- Return fixed error messages to clients; log internal details server-side only.
- Sanitize control characters in `message`, `contact`, `meta`, and debug log sections before email generation.

Suggested tests:

- Oversized fields return `413`.
- SMTP failures return a generic response without provider error text.
- Control characters do not alter generated email headers or structure.

### Low: Debug Log Still Needs a Secret-Regression Guard

Files:

- `app/lib/src/services/debug_log.dart`
- Call sites using `dlog(...)` under `app/lib/src`

Current state:

The log is in-memory and does not appear to print raw access tokens, refresh tokens, passwords, shared secrets, identity secrets, or cookies in the reviewed paths. It does log account names, Steam IDs, URLs, item names, network method names, and error messages.

Impact:

The feedback flow can include the in-app debug log. A future `dlog` call that includes a token, QR challenge URL, cookie header, or password would become an exfiltration path to the developer inbox.

Recommended fix:

- Add a centralized redaction helper for known sensitive keys and token-shaped strings.
- Add tests around the feedback payload builder or debug dump path.
- Treat `dlog` additions in review as security-sensitive.

Suggested tests:

- A string containing `access_token=...`, `steamLoginSecure=...`, `RefreshToken`, `shared_secret`, or `identity_secret` is redacted before feedback submission.

## Notable Existing Strengths

- Vault payload encryption uses AES-256-GCM with random nonces.
- Legacy maFile crypto has compatibility tests and wrong-password behavior tests.
- Vault migration has tests for legacy layouts, corrupt records, stale legacy records, and PIN rewrap.
- Android backup is disabled, matching the Keystore-held vault model.
- Export flow warns that plaintext maFiles are sensitive.
- Network logs generally avoid printing raw token values.

## Recommended Fix Order

1. Fix cross-origin redirect cookie handling.
2. Fix authenticator finalization retry timing.
3. Validate manifest filenames and enforce path containment.
4. Make manifest and payload writes crash-atomic.
5. Harden feedback worker error handling and rate limiting.
6. Add debug-log redaction tests.

## Test Coverage Gaps to Close

- Cross-origin redirect with cookies.
- Authenticator finalization `want_more` timing.
- Manifest path traversal.
- Partial write and key-rotation crash recovery.
- Feedback worker generic error responses.
- Secret redaction in debug/feedback paths.
