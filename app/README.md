# AVA — Steam authenticator (Flutter)

AVA (AnotherVaporAuth) — a modern, lightweight, cross-platform Steam
authenticator built with Flutter. Targets **Windows / macOS / Linux desktop +
Android** from a single codebase (iOS is planned). **maFiles are fully
compatible** with the legacy Steam Desktop Authenticator format for zero-cost
migration.

See the design spec: `../docs/specs/2026-06-29-flutter-rewrite-design.md`

## Architecture

```
lib/src/
  core/                 # pure Dart, no Flutter — unit-testable
    crypto/             # MaFileCrypto (PBKDF2+AES-CBC), SteamRsa
    proto/              # minimal protobuf wire codec
    models/             # SteamGuardAccount, SessionData, Manifest, Confirmation
    protocol/           # 10 Steam clients — SteamAuthSession, Confirmations,
                        #   AuthenticatorLinker, QrApproval, TradeOffers,
                        #   Market, Inventory, FamilyGroups, Sessions, StoreKey
                        #   (+ eresult / community_session: shared helpers)
    steam_totp.dart     # auth code + confirmation hash
  services/             # StorageProvider, AccountStore, SteamApiClient,
                        #   SteamTime, SessionManager
  app/                  # Riverpod providers, app shell, settings store
  ui/                   # Material 3 screens (visual style intentionally minimal)
l10n/                   # ARB localizations (en, zh, zh_Hant, de, fr, es, ru)
```

## Status (1.4.0)

Implemented and statically verified end-to-end:

- maFile compatibility (PBKDF2 50k/SHA1 + AES-256-CBC, byte-compatible)
- TOTP codes + countdown, copy, account list/reorder
- Encryption: unlock, set/change/remove passkey
- Import existing `.maFile`
- **Pending center** (tabbed): trade/market confirmations with **batch**
  accept/reject; **trade offers** (received/sent/history, expandable cards,
  accept via `IEconService` + community endpoints). Two tabs since v0.92.0 —
  family-group invites moved to the family group screen
- **Hold-to-confirm** control (settings-aware) for every irreversible action —
  accepts and account deletion — with accelerating haptics; **Hold to
  confirm** / **Hold to delete** / **Haptic feedback** toggles
- **Session-invalid notice**: a definitive InvalidPassword from the background
  refresh (password changed elsewhere) marks the account on the home screen
  and routes to re-login; network errors never mark or absolve
- **Family group** page (members, roles, slots, cooldown) — read-only apart
  from the incoming invites it now hosts: pre-join checks, then hold-to-join
  (`IFamilyGroupsService`)
- Desktop window geometry persisted and refitted to the displays present
- Inventory browse + Community Market list/cancel with live fees
- Login (username/password + **QR login**), Steam Guard code, session refresh
- Add authenticator (phone → SMS → revocation confirm)
- **Move an existing authenticator to this device** (`RemoveAuthenticatorViaChallenge*`;
  no 15-day trade hold, unlike removing it on the website)
- **QR approve** external sign-ins (direction B; scan on mobile / paste on desktop)
- **Device sessions** — list every signed-in device/browser and remotely sign one
  out (`IAuthenticationService/EnumerateTokens` + `RevokeRefreshToken`)
- **Redeem Steam product keys** — the store's own `/account/ajaxregisterkey/`
  (there is no Web API equivalent; see `docs/specs/2026-07-27-redeem-key-design.md`),
  with `EPurchaseResultDetail` mapped to per-reason copy. **Success path verified
  on a live account** (2026-07-29); the individual rejection codes and the
  receipt's field spelling are still unconfirmed
- **AVA Pro** — channel split (`play` / `cn` flavors), Ed25519 entitlement tokens
  verified offline, paywalled skins, AdMob banner + rewarded VIP (play only)
- **Block screenshots** — opt-in `FLAG_SECURE` toggle (Android only; off by
  default, since it also blanks screen sharing and feedback screenshots)
- **Versioned privacy consent** — the first-run notice is tracked by revision,
  not a boolean, so changing what it *says* re-asks instead of relying on
  agreement to different wording. Someone who accepted an earlier revision
  gets a "what changed" screen rather than the first-run welcome, and Agree
  stays disabled until the notice has been scrolled to the end (a notice that
  fits the viewport enables it immediately — see
  `test/widget/app_smoke_test.dart`)
- i18n — **seven locales**: English, 简体中文, 繁體中文, Deutsch, Français,
  Español, Русский. Each is translated from the English template, not machine
  converted; `zh_Hant` uses Taiwan vocabulary and `zh_HK` matches it by script
  rather than falling back to Simplified. System or manual language; the
  stored choice is a full BCP-47 tag, so the script subtag survives a restart.
  Adding a locale means touching **three** unconnected places — the ARB, the
  `kSelectableLocales` picker list, and `steamLanguageFor()` (miss the last
  and Steam-served item names stay English); `test/app/locales_test.dart`
  fails if they drift apart

Verification: `flutter analyze` clean, **735 tests pass** (crypto RFC vectors,
TOTP/confirmation cross-impl vectors, protobuf round-trip incl. family-groups
codec, trade-offer/model JSON, hold-button haptics, AccountStore end-to-end,
entitlement signature/grace/clock-skew, sessions-client revoke HMAC vectors,
pending-center + family-screen widget tests, app smoke render).

### Not yet verifiable here

Network flows (login, confirmations, trade offers, linking, QR-approve,
family groups) are implemented to the documented Steam protocol but require
**live Steam credentials** to integration test. Two surfaces are still
protocol-speculative until validated on a real account (see
`../docs/plans/archive/2026-07-15-family-groups.md` 执行后记): the family **join** nonce
(sent as `invite_id`) and the ePrivilege=5 pre-join **check** endpoint's
availability to ordinary user tokens. The QR-approve (direction B) signature
scheme should likewise be checked against a live capture before production use.

Both **Linux desktop and Android release builds are verified**:

- Linux desktop: release bundle ~27 MB (AOT).
- Android release: cn universal APK 91 MiB, play AAB 85 MiB (v1.2.3). Debug
  builds are far larger — 186 MB universal, 119 MB with
  `--target-platform android-arm64`, since `lib/` is ~71% of them.
  No NDK required.

```sh
flutter pub get --enforce-lockfile
flutter test                       # 735 tests
flutter build linux --release      # build/linux/x64/release/bundle (~27MB)
flutter run -d linux               # or windows / macos

# Android is flavor-split (play / cn) — a build with no --flavor FAILS.
# --flavor and --dart-define must agree; the define defaults to cn.
flutter build appbundle --flavor play --dart-define=AVA_CHANNEL=play  # Play Store
flutter build apk --flavor cn --dart-define=AVA_CHANNEL=cn            # GitHub release
flutter run --flavor cn --dart-define=AVA_CHANNEL=cn                  # day-to-day
```

Manjaro/Arch toolchain:

```sh
# desktop
sudo pacman -S --needed clang cmake ninja gtk3
# android
sudo pacman -S --needed jdk17-openjdk
# + Android cmdline-tools in ~/Android/Sdk, then:
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
flutter config --android-sdk ~/Android/Sdk
```

Notes:
- `android/build.gradle.kts` forces every plugin's `compileSdk` to 36 in
  `afterEvaluate` (file_picker 8.x pins 34, which breaks the release build).
- Release signing comes from `android/key.properties` (git-ignored). Without it,
  release APKs fall back to the debug key so `flutter run --release` still works,
  but `bundleRelease` **fails closed** — a store bundle can never ship debug-signed.

## Toolchain

Flutter 3.44.7 · Dart 3.12.2.
