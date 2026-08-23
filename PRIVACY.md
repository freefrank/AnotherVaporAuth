# Privacy Policy — AVA (AnotherVaporAuth)

**Effective date: 2026-08-15**

<sup><a href="PRIVACY.md"><b>English</b></a> · <a href="PRIVACY_ZH.md">简体中文</a></sup>

AVA ("the app") is an open-source, community-built authenticator for Steam.
It is not affiliated with Valve or Steam. This policy explains what data the app
handles and how.

**Short version:** your authenticator secrets never leave your device, and the
app contains no analytics, telemetry or crash reporting. Since v0.90 there are
two clearly-scoped exceptions, both described in full below: the optional
**AVA Pro subscription** talks to a small entitlement service we operate
(Section 4), and the **free tier of the Google Play version shows ads** via
Google AdMob (Section 5). The direct-download (cn) build contains no
advertising code at all.

## 1. Data stored on your device

The app stores the following **locally, on your device only**:

- **Steam Guard authenticator data** (maFiles): shared secret, identity secret,
  revocation code, SteamID, account name, device ID.
- **Session tokens** (access and refresh tokens) used to talk to Steam.
- **Your Steam password — optional.** Only if you choose to save it (to enable
  automatic session refresh). It is stored inside that account's maFile.
- **Cached profile data**: avatar/frame image URLs and display (persona) name.
- **App settings**: theme, language, and your app-unlock PIN material.
- **Pro entitlement state** (if you unlock AVA Pro): a signed entitlement
  token and a random per-install identifier (see Section 4). Neither contains
  or is linked to your Steam data.
- **A short debug log** (Settings → Debug log), kept in memory only and cleared
  when the app closes.

Authenticator data at rest is encrypted with **AES-256-GCM** using a random key
held in your device's hardware-backed **Android Keystore** and unwrapped by your
6-digit unlock PIN (and, if enabled, your device biometrics / device
credential). Because the key is bound to your device's keystore, copies of the
data files are useless on any other device. None of it reaches us.

## 2. Data we collect

**No analytics, telemetry, crash reporting, or tracking.** There is no account
with us. Beyond the direct Steam traffic the app needs to function, data
reaches us (the developer) in exactly three cases, each initiated by you:

1. feedback you compose and send yourself (Section 3);
2. the optional AVA Pro subscription (Section 4);
3. ad delivery by Google AdMob on the free tier of the Play version — this
   data goes to Google, not to us (Section 5).

## 3. Network connections

To function, the app connects **directly to Valve's official Steam services**,
including:

- `steamcommunity.com` and `api.steampowered.com` — authentication,
  confirmations, sign-in requests, profile data.
- Steam content CDNs (e.g. `*.steamstatic.com`) — avatar and frame images.

These requests go straight from your device to Valve. Your use of Steam through
the app is subject to Valve's own
[Steam Privacy Policy](https://store.steampowered.com/privacy_agreement/).

**Settings → Feedback** is entirely opt-in: nothing is transmitted unless you
press send. When you do, your message, the optional contact field, and one
metadata line shown verbatim in the form (app version, platform, language) are
delivered to `ava-feedback.dotslash.pro` — a relay operated by the developer
that forwards the report as an e-mail to the developer's mailbox and stores
nothing else. If you tick **"Attach debug log"** (off by default), the in-app
debug log is included too — recent network-trace lines that may contain your
account names and SteamIDs, but never your secrets, tokens or passwords. Like
any web request, the relay sees your IP address; it is included in the
forwarded e-mail and kept nowhere else.

**Update check** (added in v1.3): once per launch, the app asks
`api.ava.dotslash.pro/v1/version` whether a newer release exists. The
request carries no account data and no identifier — the endpoint sees your
IP address (as any web request does; the request travels over Cloudflare's
network, whose edge infrastructure we do not control) and answers a static
version table. The endpoint stores nothing and keeps no logs. You can turn
the check off in **Settings → Check for updates on launch**; the app never
blocks or waits on it, and works identically offline.

**Sync** (optional, v1.2): if — and only if — you configure sync, the app
connects to **the WebDAV server you specified**. What travels there is
described in Section 9; in short, ciphertext encrypted on your device.

The app additionally contacts `api.ava.dotslash.pro` — the AVA Pro entitlement
service — only in the situations described in Section 4, and Google's ad
services only as described in Section 5.

## 4. AVA Pro subscription (optional)

AVA Pro is an optional paid tier (theme packs; ad removal on the Play
version). The app is fully functional without it. If you never use the Pro
screen, nothing in this section applies and the entitlement service is never
contacted with an identity of yours.

To operate subscriptions across reinstalls and devices we run a minimal
entitlement service (`api.ava.dotslash.pro`, hosted on Cloudflare Workers).
It processes only what subscription verification needs:

- **A random per-install identifier** generated by the app. It is not derived
  from your device hardware and is never linked to your Steam accounts.
- **Google Play channel:** the Play Billing **purchase token** of your
  subscription (verified against Google Play), and — to bind the subscription
  to you across devices — the **account identifier of the Google account** you
  pick in the Google sign-in dialog. Payment itself is handled entirely by
  Google Play; we never see your payment instruments.
- **Direct (cn) channel:** the **Afdian order number** you enter and the
  Afdian user id it resolves to (verified against Afdian's API). Payment is
  handled entirely by Afdian.
- **Beta thank-you codes**, if you redeem one.
- If you watch a rewarded ad for temporary VIP (Play version), Google's
  reward callback delivers the random install identifier to the service to
  credit the reward.

The service stores the resulting entitlement records (subscription end date,
which device classes are active, order numbers) for as long as needed to
operate your subscription, and issues short-lived signed tokens that the app
stores locally. Like any web request, the service momentarily sees your IP
address; it is not stored. Infrastructure is provided by Cloudflare;
verification calls go to Google (Play subscriptions / sign-in) and Afdian
(orders) respectively. We do not sell or share this data with anyone else.

## 5. Ads (Google Play version, free tier only)

The **Google Play version** shows a single banner ad on the home screen and
offers an optional rewarded video (watch an ad, get 3 days of VIP) — **only
while you are on the free tier**. Pro subscribers and active VIPs see no ads.
The **direct-download (cn) build contains no advertising SDK at all**.

Ads are served by **Google AdMob**. AdMob may collect and use device
information — including the **Advertising ID** — to serve and measure ads,
as described in [Google's Privacy Policy](https://policies.google.com/privacy)
and [how Google uses ad data](https://policies.google.com/technologies/ads).
Where consent is legally required (e.g. EEA/UK), a consent dialog is shown
before any ad loads, and you can revisit your choice from the in-app privacy
options. We receive aggregated ad revenue reports only — never your identity.

## 6. Permissions

- **Internet** and **network state** — to reach Steam's servers and detect
  whether the device is online.
- **Camera** (optional) — only when you scan a login QR code.
- **Biometric / fingerprint / device credential** (optional) — only to unlock
  the app.
- **Advertising ID** (Play version only) — used by Google AdMob as described
  in Section 5.

The app requests no location, contacts, or other sensitive permissions beyond
these.

## 7. Sharing your data

Your authenticator data never reaches us, so it cannot be shared. The minimal
subscription data of Section 4 is processed only by the service providers
named there (Cloudflare, Google, Afdian) and is not sold, rented, or shared
with anyone else. Ad data is exchanged between your device and Google as
described in Section 5.

## 8. Exporting your data

You can export an account's maFile from the app. An exported **unencrypted**
maFile contains your Steam Guard secrets and, if you saved it, your account
password. Anyone who obtains that file can access your account — store and share
exports carefully. They are your responsibility.

## 9. Sync between your devices (optional, off by default)

Since v1.2 the app can sync your account library — and a curated set of app
settings — between your devices, **through a server you choose and control**
(any WebDAV server: Nextcloud, a NAS, a hosted provider). This is the
opt-in online feature the previous version of this policy promised to
describe before it could be enabled. How it works:

- **Off by default.** Nothing is synced until you configure a server and a
  sync passphrase under Settings → Sync. The app keeps working fully locally
  if you never enable it.
- **Everything is encrypted on your device before upload**, under a key
  derived from your sync passphrase. The server you point the app at stores
  ciphertext only; whoever operates that server cannot decrypt your
  authenticator data without the passphrase, which never leaves your devices.
- **We run no sync server and receive nothing.** The app talks directly to
  the server you configured. Its address and credentials are stored on your
  device and are themselves excluded from sync.
- Disabling sync stops all transfers; removing the remote data is done on
  your server, which you control.

Other online features we may add (for example trade/confirmation
notifications, which may require a server component operated by us) will
follow the same rules: strictly opt-in, off by default, described by an
updated version of this policy before they can be enabled, and never
self-enabling.

## 10. Children

The app is not directed to children and is intended for Steam account holders,
consistent with Valve's own age requirements.

## 11. Changes to this policy

We may update this policy as the app evolves. Changes are published in this
file in the project repository with a new effective date. Because the app is
open source, you can review the full history of this document.

- **2026-07-16:** added Sections 4 (AVA Pro subscription) and 5 (ads on the
  Play version's free tier); updated Sections 1–3, 6 and 7 accordingly.
- **2026-07-02:** initial version.

## 12. Contact

Questions? Open an issue on the project repository:
<https://github.com/freefrank/AnotherVaporAuth>
