# alternativeto.net 登记攻略

**为什么值得做**：SDA（Steam Desktop Authenticator）早就不维护了，找替代品的人
会落到 alternativeto 的页面上。这是一次性投入、永久挂着的渠道，不像帖子会沉。

**先知道两件不愉快的事**（2026-08-08 从官方 FAQ 核实）：

- **免费审核要「至少几个月」**。付 $5 一次性优先审核，1–2 个工作日。这条自己权衡，
  但如果指望它在这一轮推广里起作用，就得付。
- **不许用任何方式换赞**（折扣、赠品都算），会触发降权。别找朋友刷。

开发者自荐是**允许的**——FAQ 原话是「you can add it yourself :) Just sign up for
an account」。但别把个人主页当广告位用。

---

## 步骤

1. 注册账号并**验证邮箱**（未验证不能提交新应用）。
2. 右上角头像 → **Suggest new application**。
3. 按下面的内容填表，提交。
4. 提交后再去把 AVA 挂到同类应用下面：进 **Steam Desktop Authenticator** 的页面
   → **Contribute to this page** → **Suggest Alternatives** → 搜 AVA 加进去。
   这一步是重点——**光有自己的页面没人会找到，被列在 SDA 的替代品列表里才有流量。**
   同样值得挂的还有 Steam Mobile、WinAuth、Steam++ / Watt Toolkit。

---

## 表单内容（直接复制）

### Name

```
AVA (AnotherVaporAuth)
```

### Platforms

Android · Windows · Linux · Mac（iOS 未发布，别勾）

### License

Open Source（MIT）· Free · Freemium
（付费档存在，别只勾 Free——被人发现比主动说糟糕得多）

### Short description（一句话）

```
Open-source Steam Guard authenticator that holds several Steam accounts in one list, on phone and desktop.
```

### Long description

```
AVA (AnotherVaporAuth) is an unofficial, open-source Steam Guard authenticator for Android, Windows, Linux and macOS, built from a single Flutter codebase. It is a community project and is not affiliated with Valve or Steam.

The official Steam mobile app holds exactly one authenticator per phone, which is why people with a main, an alt, a regional account and a few bots end up with a folder of .maFile backups and a desktop tool they have to walk over to. AVA keeps all of those accounts in one list: live Steam Guard codes, trade and market confirmations, trade offers with both sides' items shown, sign-in approval, inventory and Community Market listing, product key redemption, and a device list you can sign other machines out from — per account, on whatever machine you are at.

It reads and writes the classic .maFile format (PBKDF2/SHA1 + AES-256-CBC), so authenticators from Steam Desktop Authenticator move over unchanged, and exports from Steam++ / Watt Toolkit are imported too. You can export your .maFile at any time. It can also move an authenticator off the official Steam app using Steam's own transfer flow, which carries no 15-day trade hold.

A 6-digit PIN guards a random 256-bit key held in the device's hardware keystore; local storage is AES-256-GCM. Codes work offline — nothing is downloaded at runtime. Seven languages.

An optional subscription unlocks two themes and removes ads from the Google Play build; every security feature is free in every build. The source is MIT-licensed and can be built into a variant with no ad or billing code compiled in at all.
```

### Tags

```
steam, steam-guard, authenticator, two-factor-authentication, 2fa, totp, mafile, open-source, cross-platform, flutter
```

### URLs

| 字段 | 值 |
|---|---|
| Website | `https://ava.dotslash.pro` |
| Source code | `https://github.com/freefrank/AnotherVaporAuth` |
| Google Play | `https://play.google.com/store/apps/details?id=pro.dotslash.ava` |
| Privacy policy | `https://ava.dotslash.pro/privacy/` |

### 截图

用 `posts/shots-1.0.1/` 里的：账户列表、交易确认、设置。桌面截图用
`~/sync/Git/dotslashpro/ava/public/shots/desktop-installer.png`。

---

## 注意

- **Long description 里主动写了付费档和广告。** 这是有意的：alternativeto 的
  License 字段本来就要求区分 Free / Freemium，而漏报会被编辑改掉、也会被用户
  在评论里指出来。主动说的成本远低于被抓到。
- 描述里没有出现「best」「powerful」这类词。这个站的编辑对营销腔敏感，
  写清楚它做什么就够了。
- 提交后条目会进审核队列，**期间页面不可见**。别以为提交失败又提交一次。
