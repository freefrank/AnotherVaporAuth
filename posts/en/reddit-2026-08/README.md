# Reddit round, 2026-08

Drafts for the 1.0.1 push. Rules for every venue below were read from the
actual subreddit (via a headless browser — Reddit blocks plain fetches), not
recalled, on 2026-08-08.

## Where AVA can and cannot go

| Sub | Verdict | Why |
|---|---|---|
| **r/SteamBot** | ✅ **best fit** | Has a `[Release]` tag *for exactly this*. No self-promo rule at all — the only money rule bans "buying or selling your bots or programming services". Audience runs ASF and already lives in maFiles. Small but every reader can evaluate the thing. |
| **r/droidappshowcase** | ✅ allowed | The sister sub r/androidapps explicitly redirects dev posts here. Only ~7 months old, so reach is limited, but zero risk. |
| **r/Steam** | ⚠️ ask first | Rule 5 bans UGC that is "paid… contains ads… or made with the assistance of AI", and separately bans promoting "anything for financial gain". Modmail sent 2026-08-08; see `r-steam-modmail.md`. |
| r/opensource | ⚠️ allowed, low value | Self-promo tolerated ("we're a little more forgiving" than the 10% rule). But that audience gives stars, not users. |
| r/androidapps | ❌ forbidden | Rule 2: "Any self-promotion… are not allowed", redirects to r/droidappshowcase. |
| r/SteamSupport | ❌ off-topic | It is a help desk: "Post here if you need help with a Steam related problem". |
| r/GlobalOffensiveTrade, r/SteamGameSwap, r/indiegameswap | ❌ off-topic | Transaction boards with fixed title formats. A tool announcement is not a trade post. |
| r/tf2trade | ❌ private | Cannot post. |
| **r/ArchiSteamFarm** | ❌ **banned** | "This subreddit was banned due to being unmoderated." Banned 4 years ago. ASF's community is on Discord and GitHub Discussions now. |

## Screenshots

Live on the site, all four verified reachable:

- `https://ava.dotslash.pro/shots/home-neon.png` (1.3 MB — worth compressing)
- `https://ava.dotslash.pro/shots/home-pixel.png`
- `https://ava.dotslash.pro/shots/confirmations.png`
- `https://ava.dotslash.pro/shots/desktop-installer.png`

**Reddit text posts do not render `![](url)`** — inline images become links on both
old and new Reddit. Either post as a gallery (upload the four files) or keep them
as the plain links the drafts use.

**Unverified: how old these screenshots are.** They sit alongside 0.80-era files in
the site repo, and 1.0.1 added five languages and rewrote the consent screen. Re-shoot
before posting anywhere image-led.

## Standing constraint

`posts/` is excluded by `.git/info/exclude`, so files here need `git add -f`
to commit — and only ever file by file: `posts/zh/recruit/` holds tester
emails and live Pro codes, and `-f` overrides `.gitignore`.
