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
  Also imports other tools' variants (Steam++ / Watt Toolkit), including exports
  with no SteamID (imported as a code-only account whose codes work offline).
  Export an account's maFile at any time.
- **Steam Guard codes** — a per-account list with live countdown rings and
  tap-to-copy; tap a name to cycle username / persona / id.
- **In-app sign-in approval** — approve or deny Steam logins from a dialog inside
  AVA (device + location shown), just like the official app — by polling, no push.
- **Pending center** — one tabbed screen (swipe right on an account) for everything
  awaiting a decision: **Confirmations** (trade / market, batch accept/reject, native
  JSON, no WebView), **Trade offers** (received / sent / history, expandable cards
  with both sides' items, gift / one-sided / escrow banners, accept then hand off to
  the matching mobileconf).
- **Steam Family groups** — a read-only group page (members, roles, slots, cooldown)
  from an account's menu, where incoming invites also live: pre-join checks first,
  then hold-to-join. *(experimental)*
- **Hold-to-confirm** — every irreversible accept (a trade offer, a confirmation, a
  family join) is one press-and-hold with accelerating haptics; toggle it and the
  haptics off in Settings.
- **Inventory & Market** — browse an account's Steam inventory (Steam-style game
  picker, identical items stacked) and list items on the Community Market with
  live Steam fees, a high/low price trend, linked "you receive ⇄ buyer pays"
  pricing, batch listing, and optional auto-confirm; a "My listings" tab cancels
  active listings. Long-press an account to open it.
- **Automatic session refresh** — refreshes the access token from the refresh
  token, and (optionally) does a full headless re-login with a stored password
  plus the account's own TOTP when the refresh token expires.
- **Login flows** — password + **QR**, session refresh, add authenticator, and
  approving another device's login by scanning its QR.
- **App lock** — a mandatory 6-digit PIN gates a random 256-bit key held in the
  device's hardware Keystore, which encrypts the local store (AES-256-GCM); with
  biometric / device-credential unlock, it signs in as soon as the PIN is entered.
- **Animated avatars** — pulls each account's Steam avatar and avatar frame and
  plays them (GIF natively; APNG parsed and composited by hand, honoring each
  frame's offset / blend / dispose, so offset-based frames don't flicker).
- **Appearance & skins** — a plain **Light / Dark / follow-system** appearance,
  and separately a **skin** layer (None / Neon cyberpunk / Pixel retro), each
  skin a data-driven effect pack with its own ambience and pull-to-refresh.
- **Device management** — see every device and browser session signed into an
  account (platform, rough location, last activity) and sign any of them out
  remotely. The current device is marked and can't sign itself out.
- **Redeem Steam keys** — activate a product key on an account from its menu,
  with Steam's own rejection reasons spelled out (mistyped, already owned,
  already used, wrong country, needs the base game, rate-limited). Activation is
  permanent, so it always confirms first and never retries a key by itself.
- **First-run gesture tutorial** on touch devices (desktop gets right-click row
  menus instead).
- **i18n** — English, 简体中文, 繁體中文, Deutsch, Français, Español, Русский.
- Fully **offline**: fonts and assets are bundled, nothing is downloaded at runtime.
- **In-app Debug log** (Settings → Debug log) — a copyable network trace of the
  Steam flows for diagnostics.

## Project layout

```
app/      Flutter application (see app/README.md)
docs/     design spec (docs/specs/)
```

The **`legacy`** branch preserves the original .NET WinForms Steam Desktop
Authenticator that inspired this project — kept for reference only; AVA shares no
code with it.

## Build

Requires the Flutter SDK (3.44.x). See `app/README.md` for details.

```sh
cd app
flutter pub get --enforce-lockfile
flutter test                       # 678 tests
flutter run -d linux               # or windows / macos

# Android ships in two flavors (play / cn); a build without --flavor fails.
flutter build apk --release --split-per-abi --flavor cn --dart-define=AVA_CHANNEL=cn
```

Desktop releases are built by GitHub Actions on every `v*` tag or manual
dispatch, see `.github/workflows/desktop-release.yml`:

- **Windows installer** — a scene-style single-file `AVA-…-setup.exe` built
  from our own Flutter installer app (`installer/`): frameless neon/pixel UI,
  installs per-user (no UAC), Start-menu / desktop shortcuts and a proper
  uninstall entry. Uninstalling never touches account data.
- **Linux AppImage** — single-file `AVA-…-linux-x86_64.AppImage`.

**Portable build (Windows):** a separate workflow
(`.github/workflows/windows-portable.yml`) packs the whole app into one
single-file `AVA-…-portable.exe` (Enigma Virtual Box). It runs from anywhere
with nothing to install; account data is stored in the regular per-user data
directory, same as the installed build.

## macOS (Apple Silicon)

DMG builds ship on [Releases](https://github.com/freefrank/AnotherVaporAuth/releases)
starting with the next tagged version — **arm64 only** (M1 and later; no Intel
build). Open the DMG and drag **AVA** into **Applications**.

The app is ad-hoc signed but **not notarized** (a $99/year Apple Developer
membership; this is a free community project), so Gatekeeper will warn on first
launch. To run it anyway:

1. **Right-click** (or Control-click) `AVA.app` → **Open** → **Open**. On newer
   macOS the button may only appear the second time, or under
   **System Settings → Privacy & Security → "Open Anyway"**.
2. If macOS instead claims the app "is damaged and can't be opened" — that is
   the quarantine flag on an un-notarized download, not actual damage. Clear it:

   ```sh
   xattr -dr com.apple.quarantine /Applications/AVA.app
   ```

Both are one-time; later launches open normally. Only ever do this for software
whose origin you trust — for AVA that means this repo's Releases page, where
every DMG is built in public by GitHub Actions from the tagged commit.

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

AVA is an independent project, written from scratch in Flutter — not a fork or
port. It was inspired by the classic **Steam Desktop Authenticator** (by
Jessecar96 and contributors), and stays compatible with its `.maFile` format so
existing users can migrate. Steam auth protocol references:
[SteamAuth](https://github.com/geel9/SteamAuth),
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session).

## Privacy

Your Steam data has no backend: accounts, secrets and codes stay on your device
and every Steam request goes straight to Valve. Three other services are
involved and are named here rather than buried — Pro entitlement checks, in-app
feedback (only when you press send), and ads on the Play build's free tier. The
full [Privacy Policy](PRIVACY.md) ([简体中文](PRIVACY_ZH.md)) covers each.

## License

See [LICENSE](LICENSE). Bundled fonts retain their own OFL 1.1 licenses.
