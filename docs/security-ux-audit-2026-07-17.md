# Security & UX Audit + Fix Batch — AVA

Date: audit 2026-07-17, fixes landed 2026-07-18
Mode: multi-agent audit (whole app) followed by an implementation batch; every fix pinned by a regression test.
Scope: Flutter app (`app/`) — storage/vault, Steam protocol clients, billing/entitlement, market, move-in, import, l10n. The entitlement worker was read but not modified (follow-up in flight, see "Remaining work").

## Method

Three adversarially-verified review rounds, each finding independently re-verified before being accepted:

| Round | Scope | Candidates | Confirmed → acted on |
|---|---|---|---|
| 1 | whole app, 6 finder angles | 51 | 49 verified; top 15 fixed, 31 lower-severity triaged separately, 2 refuted |
| 2 | the fix diff itself | 34 | 15 fixed (incl. 4 bugs introduced by round-1 fixes) |
| 3 | round-2's fix diff | 19 | 10 fixed, 2 refuted |

Final state: `flutter analyze` clean, 403 tests green (~+100 vs. baseline). Landed as commits `ca81ecf`..`2449363` (7 topic commits + 1 docs).

## What was fixed (by theme)

**Irreversible data loss.** Move-in could discard the only copy of a freshly swapped-in `shared_secret` if the route was popped mid-request (`!mounted` early-return between the irreversible `moveInContinue` and `persistAccount`); now persists regardless of unmount, blocks pop only during the irreversible window, and a failed save arms a root-level rescue screen that survives system back. Concurrent `saveAccount` calls on a legacy encrypted store could delete both ciphertext slots (alt-slot two-phase commit raced on the shared manifest); AccountStore now serializes all writers behind a future-chained mutex with a post-await re-check before deletes. `migrateToVault` dropped entries whose maFile failed to decrypt; they are now preserved verbatim. A lost `manifest.json` was a dead-end raw-exception screen; it now boots into a recovery screen (retry / guarded reset / evidence-gated vault-manifest rebuild, mtime-aware slot choice).

**Money paths.** `subscribeViaPlay` ran the acknowledged Billing purchase *before* a sign-in step guaranteed to fail while `kGoogleServerClientId` is empty — a user could be charged and never entitled. Sign-in now precedes the charge and both flows fail fast when unconfigured. The sell sheet's input formatter silently deleted `,` (comma-decimal input listed at 100×); price parsing now accepts `,` as a decimal separator and rejects ambiguous thousands shapes outright. Batch listing reports partial success, mid-batch session expiry, and partial auto-confirms truthfully.

**Session & protocol.** Five UI sites "persisted" renewed tokens via `store.save()`, which writes only `manifest.json` — rotated refresh tokens died with the process and every restart repeated the sign-in dance; all five now persist the payload via `persistSession` (which grafts onto the loaded instance and refuses to resurrect a removed account). `communityGetJson/PostJson` ignored HTTP status, so 302-to-login/401 empty bodies decoded to `{}` and read as success (cancel-listing claimed success; confirmations showed the unrecoverable "wrong secret" message). A status gate now maps auth-shaped failures (401/403, login redirects incl. `steammobile://lostauth`) to `CommunityAuthException` routed to each surface's sign-in affordance, passes 4xx JSON diagnostic bodies through, and turns everything else into explicit failures.

**Entitlement.** A stored token failing local verification (key rotation) stranded paying users at free forever; it is now retried against the worker and cleared only on a definitive 403. `proStatusProvider` never re-evaluated with time, so exp+grace was unenforced in long sessions; it now self-schedules at verdict boundaries. Every platform reported `device_class: 'android'`; desktop now reports its real class.

**Other.** Debug-log redaction missed `/`-containing padded base64 secrets (~1/3 of Steam secrets); a padding-anchored pass closes it. The legacy keystore password copy was never cleared after migration and resurrected passwords the user had deleted. New feature: importing a maFile whose steamId already exists prompts overwrite-vs-cancel with an honest merge-policy description.

## Deliberate decisions (do not "fix" back)

- `importMaFileContents` is *not* wrapped by the store writer lock (it calls the locked `saveAccount`; wrapping would deadlock the non-reentrant chain).
- 4xx **with** a JSON object body returns the parsed body instead of throwing — Steam's diagnostic messages must reach the UI; only auth-shaped and empty-body failures throw.
- A pre-finalize save failure in the add flow deliberately does **not** arm the rescue screen: nothing is attached on Steam's side yet, and the rescue copy's "old authenticator is dead" would be false.
- `_Root` uses `skipLoadingOnReload: true` — Riverpod 3 auto-retries a failed bootstrap and the error/recovery screens would otherwise only flash between retries.
- Equal-mtime tie in `rebuildVaultManifest` prefers the bare slot (remove-then-relink race); the migration-era rank (`.v2` first) applies only when mtimes are unknowable.

## Remaining work

- ~~31 lower-severity round-1 items~~ — resolved 2026-07-18 as batch 3 (commits `e77c3aa`..`1bac636`): 5 were already fixed by the main batch, 25 fixed across two waves (finalize evidence signal, ProtoReader bounds checks, reorder-by-steamId, paywall vocabulary, session-retry unification, perf, dedup, dead code), 1 accepted as a loss (below).
- ~~Entitlement worker per-device-class activation~~ — implemented (commit `e77c3aa`); **production deploy pending, user-run**: see `docs/plans/2026-07-16-paywall-prerequisites.md` §7 for the ordered runbook (audit query → D1 migration → worker deploy).
- Play billing configuration (`kGoogleServerClientId` + worker Google secrets) — **on hold** per 2026-07-18 decision; see `docs/plans/2026-07-16-paywall-prerequisites.md`.

## Accepted losses

- **Stale Pro launcher icon for lapsed-Pro upgraders (round-1 item O1).** Pre-0.90.1 users who had Pro + the pixel skin selected keep the pixel home-screen icon even if Pro lapses: the launcher-icon feature was retired (ColorOS force-stops apps that toggle their own components in the foreground) and its plumbing deleted in batch 3, so no reconcile path exists. In-app rendering is correctly gated; only the static icon can linger, for a small cohort. Accepted until a zero-component-write icon mechanism exists — any future re-design must fold "icon reconcile on entitlement change" into its requirements.
