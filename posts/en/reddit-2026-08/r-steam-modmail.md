# r/Steam — modmail (sent 2026-08-08)

Not a post. r/Steam Rule 5 bans UGC that is "paid, restricted in any way,
contains ads or trackers, or… made with the assistance of AI", and separately
bans promoting "anything for financial gain". The rules page itself invites a
request for exceptions, so this asks first rather than posting and being
removed.

Kept here because the reply — whatever it is — decides whether r/Steam is ever
a venue, and because the framing took a few passes to get right.

**Subject**

```
Can I mention my open-source Steam authenticator here? Checking first because of Rule 5
```

**Body**

---

Hi mods,

Asking before posting instead of after, because Rule 5 pretty clearly touches my project and I'd rather get a straight no than a removal.

I wrote a thing called AVA — an MIT-licensed Steam Guard authenticator for Android, Windows, Linux and macOS. It reads and writes the old `.maFile` format, so anything from Steam Desktop Authenticator just moves over. https://github.com/freefrank/AnotherVaporAuth

**Why I think it's relevant here and not just my pet project:** it's built for people with more than one account. A main, an alt, a regional account for pricing, a few bots on ASF — and one phone that will only hold a single Steam Mobile authenticator. So you end up with a folder of `.maFile`s and SDA running on some desktop you have to walk over to. AVA keeps all of them in one list: codes, trade and market confirmations, sign-in approvals, inventory and Community Market, and a device list you can sign other machines out from, per account, on whatever machine you're at.

The `.maFile` part matters more than it sounds. ASF takes maFiles too, so it's literally the same files in both places — the bots keep farming, and you get a readable list of codes and confirmations for the same accounts instead of a directory of JSON. That's the itch I actually had; I didn't set out to write an app.

**Now the parts you'll want to know about:**

There's a paid tier and the Play build shows ads to free users. Rule 5 names both, so I'm not going to try to talk my way around it. For proportion: the paid tier unlocks two themes. That's it. Codes, confirmations, sign-in approval, device management, `.maFile` import and export are free everywhere and always will be. You can also build it yourself into a variant with **no ad or billing code compiled in at all** — those dependencies are excluded from that build target, not disabled at runtime, and it's four lines of `android/app/build.gradle.kts` if you want to check.

It's also new — 1.0 landed in July — so "unestablished UGC" is a fair call.

One genuine question rather than a claim: it's developed with AI assistance and the commit history doesn't hide it. I read Rule 5's "made with the assistance of AI" as being about generated filler rather than about how software gets written now, but you wrote the rule and I didn't. If you mean it literally, say so and I'll drop this.

So — is there a version of this you'd be OK with? I'll take your call either way.

Last thing, since you shouldn't have to drag it out of me: a third-party tool that wants your `.maFile` looks exactly like the thing Rule 6 exists to stop. That's a reasonable reflex and I don't expect to be taken on trust. Source is public, releases are built by GitHub Actions straight from tagged commits, and the privacy policy names every server the app talks to.

Thanks for reading this far.

---

## Why it reads the way it does

- **Volunteering the paid tier and the ads.** They are unarguable under Rule 5,
  and denying them would be found out in one click.
- **AI framed as a question, not a confession.** The rule says "made with the
  assistance of AI", which on its face covers this — but self-applying a
  violation label decides the case for them. Asking leaves room for the reading
  that the rule targets generated filler.
- **The ask is deliberately open.** An earlier draft pre-limited it to "just let
  me comment when someone asks for an SDA alternative", which discounts the
  request before the mods have said anything.
- **Rule 6 raised unprompted.** A third-party tool asking for maFiles has the
  exact shape of a phishing tool. Better to name it than to be asked.
