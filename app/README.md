# SDA — Flutter rewrite (v0.9.0)

A modern, lightweight, cross-platform rewrite of Steam Desktop Authenticator in
Flutter. Targets **Windows / macOS / Linux desktop + Android** from a single
codebase (iOS is planned). Logic is kept equivalent to the legacy .NET app and
**maFiles are fully compatible** for zero-cost migration.

See the design spec: `../docs/superpowers/specs/2026-06-29-flutter-rewrite-design.md`

## Architecture

```
lib/src/
  core/                 # pure Dart, no Flutter — unit-testable
    crypto/             # MaFileCrypto (PBKDF2+AES-CBC), SteamRsa
    proto/              # minimal protobuf wire codec
    models/             # SteamGuardAccount, SessionData, Manifest, Confirmation
    protocol/           # SteamAuthSession, ConfirmationsClient,
                        #   AuthenticatorLinker, QrApprovalClient
    steam_totp.dart     # auth code + confirmation hash
  services/             # StorageProvider, AccountStore, SteamApiClient,
                        #   SteamTime, SessionManager
  app/                  # Riverpod providers, app shell, settings store
  ui/                   # Material 3 screens (visual style intentionally minimal)
l10n/                   # ARB localizations (en, zh)
```

## Status (0.90)

Implemented and statically verified end-to-end:

- maFile compatibility (PBKDF2 50k/SHA1 + AES-256-CBC, byte-compatible)
- TOTP codes + countdown, copy, account list/reorder
- Encryption: unlock, set/change/remove passkey
- Import existing `.maFile`
- Trade/market confirmations with **batch** accept/reject (native JSON, no WebView)
- Login (username/password + **QR login**), Steam Guard code, session refresh
- Add authenticator (phone → SMS → revocation confirm)
- **QR approve** external sign-ins (direction B; scan on mobile / paste on desktop)
- i18n (English + 简体中文), system or manual language

Verification: `flutter analyze` clean, **34 tests pass** (crypto RFC vectors,
TOTP/confirmation cross-impl vectors, protobuf round-trip, lossless model JSON,
AccountStore end-to-end, app smoke render).

### Not yet verifiable here

Network flows (login, confirmations, linking, QR-approve) are implemented to the
documented Steam protocol but require **live Steam credentials** to integration
test. The QR-approve (direction B) signature scheme in particular should be
checked against a live capture before production use.

Platform binaries were **not** built in the dev container (no Android SDK / no
clang+cmake+ninja). Build on a machine with the toolchains:

```sh
flutter pub get
flutter test                 # run the suite
flutter run -d linux         # or windows / macos
flutter build apk            # Android (needs Android SDK)
```

## Toolchain

Flutter 3.44.4 · Dart 3.12.2.
