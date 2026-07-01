# Privacy Policy — AVA (AnotherVaporAuth)

**Effective date: 2026-07-01**

<sup><a href="PRIVACY.md"><b>English</b></a> · <a href="PRIVACY_ZH.md">简体中文</a></sup>

AVA ("the app") is a free, open-source, community-built authenticator for Steam.
It is not affiliated with Valve or Steam. This policy explains what data the app
handles and how.

**Short version:** the app has no backend of its own. We (the developers) run no
servers, collect nothing, and have no access to your data. Everything stays on
your device. The only network connections the app makes are directly to Valve's
official Steam servers, which are required for it to work.

## 1. Data stored on your device

The app stores the following **locally, on your device only**:

- **Steam Guard authenticator data** (maFiles): shared secret, identity secret,
  revocation code, SteamID, account name, device ID.
- **Session tokens** (access and refresh tokens) used to talk to Steam.
- **Your Steam password — optional.** Only if you choose to save it (to enable
  automatic session refresh). It is stored inside that account's maFile.
- **Cached profile data**: avatar/frame image URLs and display (persona) name.
- **App settings**: theme, language, and your app-unlock PIN material.
- **A short debug log** (Settings → Debug log), kept in memory only and cleared
  when the app closes.

At rest this data is encrypted with **AES-256** using a key derived from your
6-digit unlock PIN (and, if enabled, gated behind your device biometrics /
device credential). We never receive any of it.

## 2. Data we collect

**None.** The app contains no analytics, telemetry, advertising, crash
reporting, or tracking of any kind. There is no account with us, and no server
that belongs to us.

## 3. Network connections

To function, the app connects **directly to Valve's official Steam services**,
including:

- `steamcommunity.com` and `api.steampowered.com` — authentication,
  confirmations, sign-in requests, profile data.
- Steam content CDNs (e.g. `*.steamstatic.com`) — avatar and frame images.

These requests go straight from your device to Valve. Your use of Steam through
the app is subject to Valve's own
[Steam Privacy Policy](https://store.steampowered.com/privacy_agreement/). The
app makes **no connection to any server operated by the AVA developers**, because
none exists.

## 4. Permissions

- **Internet** — to reach Steam's servers.
- **Camera** (optional) — only when you scan a login QR code.
- **Biometric / device credential** (optional) — only to unlock the app.

The app requests no location, contacts, or other sensitive permissions beyond
these.

## 5. Sharing your data

We do not share your data because **we do not have it**. The app does not sell,
rent, or transmit your data to any third party other than Valve (as required for
the app to work).

## 6. Exporting your data

You can export an account's maFile from the app. An exported **unencrypted**
maFile contains your Steam Guard secrets and, if you saved it, your account
password. Anyone who obtains that file can access your account — store and share
exports carefully. They are your responsibility.

## 7. Cloud sync (not currently available)

The current version has **no cloud or account-sync features**. All data is local,
as described above.

If a future version adds optional cloud sync or backup, it will:

- be **strictly opt-in and off by default**;
- be described by an **updated version of this policy before you enable it**,
  stating exactly what is synced, where it is stored, and how it is protected
  (the design intent is **end-to-end encryption**, so that only your device holds
  the keys);
- **never** enable itself or upload your data without your explicit action.

Until then, no data ever leaves your device except the direct Steam requests in
Section 3.

## 8. Children

The app is not directed to children and is intended for Steam account holders,
consistent with Valve's own age requirements.

## 9. Changes to this policy

We may update this policy as the app evolves (for example, if cloud sync is
introduced). Changes are published in this file in the project repository with a
new effective date. Because the app is open source, you can review the full
history of this document.

## 10. Contact

Questions? Open an issue on the project repository:
<https://github.com/freefrank/AnotherVaporAuth>
