<h1 align="center">
  <img src="icon.png" height="64" width="64" />
  <br/>
  AVA
</h1>

<p align="center">
  <b>A</b>nother<b>V</b>apor<b>A</b>uth — a modern, lightweight, cross-platform
  authenticator for Steam, built with <b>Flutter</b>.<br/>
  <sup>Community project — not affiliated with Steam or Valve in any way.</sup>
</p>

<p align="center">
  <b>Windows · macOS · Linux · Android</b> from a single codebase (iOS planned).
</p>

<p align="center">
  <b>English</b> · <a href="README_ZH.md">简体中文</a>
</p>

---

> **Security note:** a desktop/PC authenticator defeats much of the purpose of
> two-factor authentication — if your device is compromised, so is your token.
> Prefer Steam's official mobile app where you can. Always back up your `maFiles`
> and your revocation code. Use at your own risk.

## Highlights

- **maFile compatible** — reads/writes the legacy `.maFile` format
  (PBKDF2/SHA1 + AES-256-CBC), so existing accounts migrate with no changes.
  Export an account's maFile at any time.
- **Steam Guard codes** — a per-account list with live countdown rings and
  tap-to-copy; tap a name to cycle username / persona / id.
- **In-app sign-in approval** — approve or deny Steam logins from a dialog inside
  AVA (device + location shown), just like the official app — by polling, no push.
- **Trade / market confirmations** — batch accept/reject (native JSON, no WebView).
- **Automatic session refresh** — refreshes the access token from the refresh
  token, and (optionally) does a full headless re-login with a stored password
  plus the account's own TOTP when the refresh token expires.
- **Login flows** — password + **QR**, session refresh, add authenticator, and
  approving another device's login by scanning its QR.
- **App lock** — a mandatory 6-digit PIN encrypts the local store (AES-256), with
  biometric / device-credential unlock; it signs in as soon as the PIN is entered.
- **Animated avatars** — pulls each account's Steam avatar and avatar frame and
  plays them (GIF natively, APNG decoded frame-by-frame).
- **Two full themes** — Neon (cyberpunk ambience + glow) and Pixel (retro
  starfield) — switchable in settings, each with its own pull-to-refresh.
- **i18n** (English + 简体/繁體 Chinese) with more locales planned.
- Fully **offline**: fonts and assets are bundled, nothing is downloaded at runtime.
- **In-app Debug log** (Settings → Debug log) — a copyable network trace of the
  Steam flows for diagnostics.

## Project layout

```
app/      Flutter application (see app/README.md)
docs/     design spec (docs/superpowers/specs/)
```

The original .NET WinForms implementation is preserved on the **`legacy`** branch.

## Build

Requires the Flutter SDK (3.44.x). See `app/README.md` for details.

```sh
cd app
flutter pub get
flutter test                       # analyze + 39 tests
flutter run -d linux               # or windows / macos
flutter build apk --release --split-per-abi
```

Releases are built automatically by GitHub Actions on every `v*` tag
(Android APKs + Linux + Windows), see `.github/workflows/release.yml`.

## Fonts

All fonts are **bundled** (no runtime download) and declared in
`app/pubspec.yaml`; see `app/assets/fonts/README.md` for details.

| Family | Theme | Role | Source / License |
|---|---|---|---|
| [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) | Neon | display | OFL 1.1 |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) | Neon | code | OFL 1.1 |
| [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | Neon | Chinese (CJK) fallback | OFL 1.1 |
| [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font) | Pixel | display + code (Latin + full CJK incl. 簡/繁, kana, hangul) | OFL 1.1 |

The Pixel theme uses the **full** Fusion Pixel font for complete CJK coverage
(including rare characters in usernames). Noto Sans SC is subset to the CJK
ideograph blocks (simplified + traditional). Latin-only fonts cover ASCII.

## Credits

Original Steam Desktop Authenticator by Jessecar96 and contributors. Steam auth
protocol references: [SteamAuth](https://github.com/geel9/SteamAuth),
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session).

## License

See [LICENSE](LICENSE). Bundled fonts retain their own OFL 1.1 licenses.
