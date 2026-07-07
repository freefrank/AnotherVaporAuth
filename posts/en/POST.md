# Reddit post (r/AndroidClosedTesting; screenshots in this directory: home-neon, home-pixel, confirmations, tutorial-swipe, settings)

Title: [App] AVA — open-source Steam Guard authenticator (spiritual successor to Steam Desktop Authenticator) — need 12 testers for 14 days

---

Hey everyone! I'm recruiting testers for **AVA (AnotherVaporAuth)** — an open-source Steam Guard authenticator for Android, a ground-up mobile rewrite of the classic Steam Desktop Authenticator (SDA).

Google requires new personal developer accounts to run a closed test with **12 testers opted in for 14 continuous days** before the app can go to production — that's where you come in.

## What it does

- **Steam Guard codes** for multiple accounts — tap the big code to copy, tap the name to cycle username / persona / SteamID
- **Trade & market confirmations** — swipe an account row to jump straight to its confirmation list; batch accept/reject with a guard dialog
- **QR sign-in + login approvals** — scan the Steam client QR to log in, approve new-device logins from your phone
- **Inventory browser + Community Market listing** — pick items, price them (with market price hints), list, confirm — all in one flow
- **maFile import/export** — fully compatible with the SDA format, so existing SDA users migrate seamlessly
- **Biometric unlock** (fingerprint / device credential)
- **Two complete themes** — cyber Neon and retro Pixel (see screenshots), the whole app reskins
- English + 中文, an interactive gesture tutorial on first run; desktop builds (Linux/Windows) also exist

## Security model (it's an authenticator, so let's be explicit)

- Secrets are encrypted with a **random 256-bit key held behind the Android Keystore** (AES-256-GCM) — copied files are useless off-device
- **No analytics, no backend.** Everything stays on your phone; the app talks only to Steam's official servers (plus the optional in-app feedback relay). **The beta has zero ads** (see the monetization note at the bottom — no surprises later)
- Fully **open source** (MIT) — audit it yourself:
  https://github.com/freefrank/AnotherVaporAuth

## What testers need to do

1. Comment or DM me your **Google account email** (for the testing invite)
2. Accept the invite and install the app from the Play Store link
3. **Keep it installed for 14+ days** and open it now and then
4. You do **NOT** need to link a real authenticator — exploring the UI counts as testing. If you do want to use it for real, back up your existing maFiles / revocation code first.

**Thank-you perk: every beta tester gets a lifetime Pro unlock** in the production release — covering all future Pro features, cloud sync and notifications included.

## Disclaimers

- Personal open-source project, **not affiliated with Valve or Steam**
- It's an authenticator app — evaluate it yourself before trusting it with real accounts (that's exactly why it's open source)

## Monetization plans (upfront, so nobody feels ambushed later)

- **Core security features stay free forever**: codes, confirmations, login approvals, maFile import/export will never sit behind a paywall
- The paywall only covers **extras**: theme packs, widgets — the fun stuff — plus future online features like **cloud sync** and trade notifications (sync is designed end-to-end encrypted, so only your devices hold the keys; it ships opt-in, off by default, with a privacy-policy update first):
  - **Play version**: one small banner ad; unlock extras with a one-time purchase or by watching a rewarded ad
  - **Direct build (GitHub Releases)**: ad-free; extras unlock via a donation code
- The source stays MIT — building your own unlocked copy is and will remain fair game
- And again: **beta testers get Pro for free, permanently**

Opt-in link: [will update once the developer account clears review — drop your email meanwhile]
