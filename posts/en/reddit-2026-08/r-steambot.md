# r/SteamBot

Flair/tag is **mandatory** in the title — `[Release]` is the sub's own tag for
"you've written a library, framework or code snippet you'd like to share".

**Title**

```
[Release] AVA — open-source maFile authenticator for Android + desktop
```

**Body**

---

Got tired of a folder of `.maFile`s and an SDA window on a machine across the room. MIT, Flutter, Android / Windows / Linux / macOS.

**What it does**

- Several accounts in one list — live codes, tap to copy
- Trade & market confirmations, native JSON, no WebView, batch accept/reject
- Trade offers: received / sent / history, both sides' items, gift & escrow warnings
- Sign-in approval from inside the app, device + location shown
- **Move an authenticator off the official Steam app** — emailed code, no 15-day trade hold
- Inventory + Community Market listing with live fees
- Device management — see everything signed in, sign any of it out
- Steam family groups
- Product key redemption
- Reads and writes the classic `.maFile`; also imports Steam++ / Watt Toolkit exports. Export yours any time
- Codes work offline
- 7 languages

Code: https://github.com/freefrank/AnotherVaporAuth
Screenshots + desktop downloads: https://ava.dotslash.pro
Play: https://play.google.com/store/apps/details?id=pro.dotslash.ava

**Screenshots** — [account list](https://ava.dotslash.pro/shots/home-neon.png) · [confirmations](https://ava.dotslash.pro/shots/confirmations.png) · [pixel theme](https://ava.dotslash.pro/shots/home-pixel.png) · [desktop installer](https://ava.dotslash.pro/shots/desktop-installer.png)

Paid tier unlocks two themes, Play build shows a banner to free users. Everything above is free in every build, and you can compile it without any ad or billing code at all.

Happy to go into the protocol side in the comments if anyone's interested.

---

## Notes for whoever posts this

This audience can read the code, so the comments matter more than the post.
Things worth having ready rather than writing into the body:

- `RemoveAuthenticatorViaChallengeStart` returns `eresult=OK` with a **zero-byte
  body** on success — `optional bool success` is simply absent. `Continue` does
  populate it. Branch on that field and success reads as failure. Good answer to
  have on hand; it is the kind of detail that buys credibility here.
- Moving an authenticator kills the old device's immediately and replaces the
  revocation code. The app warns before confirming, so the post does not need to.
- Not validated against live accounts: the family-group join nonce (`invite_id`)
  and the `ePrivilege=5` pre-join check; QR-approve (direction B) signatures;
  the product-key **rejection** codes (only the success path is confirmed).
  Say so if asked — this sub will respect it more than a clean sheet.
- Desktop key storage is Secret Service / Credential Manager, a weaker boundary
  than the Android hardware Keystore. Do not imply parity.
