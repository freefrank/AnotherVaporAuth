# Privacy Policy — AVA (AnotherVaporAuth)

**Effective date: 2026-07-02**

<sup><a href="PRIVACY.md"><b>English</b></a> · <a href="PRIVACY_ZH.md">简体中文</a></sup>

AVA ("the app") is a free, open-source, community-built authenticator for Steam.
It is not affiliated with Valve or Steam. This policy explains what data the app
handles and how.

**Short version:** the current version of the app has no backend of its own. We
(the developers) collect nothing automatically and have no access to your data.
Everything stays on your device, and the app talks directly to Valve's official
Steam servers, which are required for it to work. If a future version adds
optional online features (such as cloud sync or trade notifications), they will
be strictly opt-in and described in an update to this policy before you can
enable them (see Section 7).

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

At rest this data is encrypted with **AES-256-GCM** using a random key held in
your device's hardware-backed **Android Keystore** and unwrapped by your 6-digit
unlock PIN (and, if enabled, your device biometrics / device credential). Because
the key is bound to your device's keystore, copies of the data files are useless
on any other device. None of it reaches us.

## 2. Data we collect

**Nothing automatically.** The app contains no analytics, telemetry,
advertising, crash reporting, or tracking of any kind, and there is no account
with us. The only data that ever reaches the developer is feedback you
compose and send yourself (see section 3).

## 3. Network connections

To function, the app connects **directly to Valve's official Steam services**,
including:

- `steamcommunity.com` and `api.steampowered.com` — authentication,
  confirmations, sign-in requests, profile data.
- Steam content CDNs (e.g. `*.steamstatic.com`) — avatar and frame images.

These requests go straight from your device to Valve. Your use of Steam through
the app is subject to Valve's own
[Steam Privacy Policy](https://store.steampowered.com/privacy_agreement/).

The single exception is **Settings → Feedback**, which is entirely opt-in:
nothing is transmitted unless you press send. When you do, your message, the
optional contact field, and one metadata line shown verbatim in the form (app
version, platform, language) are delivered to `ava-feedback.dotslash.pro` — a
relay operated by the developer that forwards the report as an e-mail to the
developer's mailbox and stores nothing else. Like any web request, the relay
sees your IP address; it is included in the forwarded e-mail and kept nowhere
else. Beyond this user-initiated feedback, the app makes **no connection to any
server operated by the AVA developers**.

## 4. Permissions

- **Internet** and **network state** — to reach Steam's servers and detect
  whether the device is online.
- **Camera** (optional) — only when you scan a login QR code.
- **Biometric / fingerprint / device credential** (optional) — only to unlock
  the app.

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

## 7. Cloud sync and other online features (not currently available)

The current version has **no cloud sync, cloud backup, or push-notification
service**. All data is local, as described above.

We do plan optional online features — for example **cloud sync/backup** of your
authenticator data, or **trade/confirmation notifications** (which may require a
server component operated by us). Any such feature will:

- be **strictly opt-in and off by default** — the app keeps working fully
  locally if you don't enable it;
- be described by an **updated version of this policy before you can enable
  it**, stating exactly what data is involved, where it is stored, and how it
  is protected (for synced secrets the design intent is **end-to-end
  encryption**, so that only your devices hold the keys; for notifications,
  the minimum data needed to deliver them);
- **never** enable itself or upload your data without your explicit action.

Until then, no data leaves your device except the direct Steam requests and the
opt-in feedback described in Section 3.

## 8. Children

The app is not directed to children and is intended for Steam account holders,
consistent with Valve's own age requirements.

## 9. Changes to this policy

We may update this policy as the app evolves (for example, when cloud sync or
notifications are introduced). Changes are published in this file in the project repository with a
new effective date. Because the app is open source, you can review the full
history of this document.

## 10. Contact

Questions? Open an issue on the project repository:
<https://github.com/freefrank/AnotherVaporAuth>
