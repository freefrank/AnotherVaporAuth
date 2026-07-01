# Changelog · 更新日志

All notable changes to **AVA (AnotherVaporAuth)**. Each version has an English
block followed by a 中文 block. The format follows
[Keep a Changelog](https://keepachangelog.com/); `v<MAJOR.MINOR>` tags trigger
automated releases.

## [v0.63] — 2026-07-01

### Added
- **Inventory & Market**: browse an account's Steam inventory (Steam-style game
  picker, identical items stacked with a ×count badge) and list items on the
  Community Market. The sell sheet shows the market price and a high/low price
  trend, linked "you receive ⇄ buyer pays" fields with Steam's live fees, a
  quantity stepper (with Max) for batch listing, and an optional auto-confirm.
  A "My listings" tab shows and cancels active listings. Reached by
  long-pressing an account. All native JSON — no WebView.

### Changed
- **Save password** is now a checkbox in the sign-in screen (on by default),
  covering both adding a new authenticator and refreshing an existing account's
  session. The redundant long-press "Save password" action was removed; a
  long-press now opens Inventory & Market directly.

—

### 新增
- **库存与市场**：浏览账户的 Steam 库存（像 Steam 一样按游戏选择，相同物品堆叠并带
  ×数量角标），并把物品上架到社区市场。上架弹窗显示市场价与最高/最低成交走势、
  「你到手 ⇄ 买家支付」联动（实时 Steam 费率）、数量步进器（含「最大」）批量上架，
  以及可选的上架后自动确认；「我的在售」页可查看/撤销。从账户长按菜单进入。全程原生
  JSON，无 WebView。

### 变更
- **保存密码** 改为登录界面里的一个勾选框（默认勾选），同时覆盖新增验证器和刷新已有
  账户会话两条路径。移除了冗余的长按「保存密码」；长按现在直接进入库存与市场。

## [v0.62] — 2026-07-01

### Added
- **Privacy Policy** (EN + 中文), linked from Settings → About, with a first-run
  consent gate. No network request is made until you accept.

### Fixed
- **Trade / market confirmations**: accepting or rejecting now works again.
  Steam's react `mobileconf` endpoint requires the accept/deny call to be a POST
  form body (it was being sent as a GET query).

—

### 新增
- **隐私政策**（中英双语），设置 → 关于 内可查看，并在首次启动时需要同意。接受前不发起
  任何网络请求。

### 修复
- **交易 / 市场确认**：批准或拒绝恢复正常。Steam 的 react 版 `mobileconf` 端点要求
  批准/拒绝以 POST 表单体发送（之前发成了 GET query）。

## [v0.61] — 2026-06-30

### Added
- **Automatic session refresh**: the access token is refreshed from the refresh
  token as needed, and — when the refresh token is dead — AVA can do a full
  headless re-login using a stored password plus the account's own TOTP. Runs on
  app open / unlock (only for stale tokens) and on demand.
- **Password storage**: long-press an account → Save password (verified by a
  real headless login) or Clear it. The password is kept in the maFile so it
  travels with the account. Note: the unencrypted export then contains it.
- **Full pixel theme**: a retro backdrop (pixel grid, drifting starfield, corner
  brackets), a blocky pull-to-refresh, sticker-style account rows and chunky
  swipe buttons; the account list is translucent over the starfield.
- **Floating settings button** in the bottom-right; the top header is gone.

### Changed
- The unlock screen now signs in automatically once the 6-digit PIN is entered —
  no confirm tap needed.

—

### 新增
- **自动刷新登录**：access token 按需用 refresh_token 刷新；当 refresh_token 也失效
  时，可用保存的密码 + 账户自身 TOTP 无界面全量重登。开 app / 解锁（仅刷新快过期的）
  及按需触发。
- **密码存储**：长按账户 → 保存密码（经真实无界面登录验证）或清除。密码存于 maFile，
  随账户走。注意：导出的未加密 maFile 会含明文密码。
- **完整像素主题**：复古背景（像素网格、漂移星场、角框）、方块下拉刷新、贴纸式账户行、
  复古滑动按钮；账户列表半透明透出星场。
- **右下角浮动设置按钮**；顶部 header 已移除。

### 变更
- 解锁界面输满 6 位 PIN 即自动登录，无需点确认。

## [v0.60] — 2026-06-30

### Added
- **About section in Settings**: source code / author / license links, an
  open-source licenses page, and a credits note.
- **Reduce-motion support**: honours the OS "reduce motion" setting — freezes the
  scanlines and the pull-to-refresh sweeps, and swaps the code flip and name
  switch for a plain fade.

### Changed
- Account-row swipe actions restyled to the neon HUD look (glassy fill, neon
  border, semantic per-action colours) and now render equal-height.
- Removed the large Trade Confirm button from the main panel — trade
  confirmations are still one right-swipe away on the account row.
- Tapping the code now gives press feedback; the add-account button has a larger
  touch target with the same 24px visual.

—

### 新增
- **设置「关于」页**：源码 / 作者 / 许可证链接、开源许可证页、致谢说明。
- **减弱动态效果支持**：跟随系统「减弱动态效果」设置——冻结扫描线与下拉扫光,验证码
  翻牌和名称切换降级为纯淡入。

### 变更
- 账户行滑动操作改为霓虹 HUD 风格(玻璃底、霓虹边框、按语义分色),并统一为等高。
- 移除主面板的大号「交易确认」按钮——右滑账户行仍可进入交易确认。
- 点击验证码有按压反馈;「添加账户」按钮触摸区域更大(24px 视觉不变)。

## [v0.59] — 2026-06-30

### Added
- **In-app sign-in approval**: approve or deny Steam logins from a dialog inside
  AVA (device + location shown), like the official app — by polling, no push.
  Polls on open, on tapping an account, and on pull-to-refresh.
- **Animated avatars & frames**: pull each account's animated avatar and avatar
  frame and play them (GIF natively; APNG decoded frame-by-frame). The static
  avatar and persona (display) name are fetched too.
- **Name switching**: tap the panel name to cycle username → persona → id (with
  an animated transition); long-press to copy.
- **Cyberpunk neon UI** (neon theme only): a full-screen neon pull-to-refresh,
  always-on ambience (drifting grid, breathing glows, radar sweep, digital rain,
  a corner HUD) and per-account glow borders. The pixel theme is unchanged.

### Changed
- **Add authenticator**: when the account already has an authenticator, AVA now
  guides you through removing the existing one instead of just failing.
- **Sign-in refresh** auto-fills the device code and can reuse a saved password,
  so refreshing a session is mostly hands-free.
- Bigger avatars and account-list fonts; tap the code to copy it (the copy
  button is gone) and the code now shares a row with the countdown ring.
- Steam `EResult` error codes are shown with readable names.

### Fixed
- Windows and Linux desktop release builds (libsecret/jsoncpp on Linux, the MSVC
  `<experimental/coroutine>` error on Windows).

—

### 新增
- **应用内批准登录**：在 AVA 内弹窗批准/拒绝 Steam 登录（显示设备 + 位置），与官方
  App 一致——基于轮询,无需推送。打开 App、点击账户、下拉刷新时各轮询一次。
- **动态头像与头像框**：拉取并播放每个账户的动态头像与头像框(GIF 原生播放;APNG 逐帧
  解码)。同时获取静态头像与昵称。
- **名称切换**：点主面板名称循环 用户名 → 昵称 → ID(带切换动效);长按复制。
- **赛博朋克霓虹界面**(仅霓虹主题):全屏霓虹下拉刷新、静置环境动效(漂移网格、呼吸辉光、
  雷达扫描、字符雨、四角 HUD)、账户行发光边框。像素主题保持原样。

### 变更
- **添加验证器**:当账户已有验证器时,AVA 会引导你移除现有验证器,而不是直接报错。
- **登录刷新**自动填写设备验证码并可复用已保存的密码,刷新会话基本无需手动操作。
- 头像与账户列表字体放大;点击验证码即可复制(复制按钮已移除),验证码与倒计时圈同行。
- Steam `EResult` 错误码以可读名称显示。

### 修复
- Windows、Linux 桌面发布构建(Linux 的 libsecret/jsoncpp,Windows 的 MSVC
  `<experimental/coroutine>` 报错)。

## [v0.58] — 2026-06-30

### Added
- **App lock**: a mandatory 6-digit unlock PIN protects the local store; the
  store can be encrypted even with no accounts.
- **Biometric / device-credential unlock**: unlock with a fingerprint or the
  device PIN/pattern/password (the passkey is held in the Android keystore);
  manual PIN entry stays as a fallback.
- **Export maFile**: account menu → export an account as an unencrypted
  `<username>.maFile` via the system share sheet.

### Changed
- **Unlock is ~instant**: AVA's PIN store uses minimal PBKDF2 rounds (a 6-digit
  PIN is keyspace-limited, so high rounds add no real security) and decrypts off
  the slow path; old stores migrate automatically on first unlock. Dropped from
  ~15s to tens of ms.
- **No launch logo / white flash**: the launch screen is AVA's dark background
  with a transparent Android 12+ splash icon.

—

### 新增
- **应用锁**：强制 6 位解锁 PIN 保护本机数据；空账户也可加密。
- **指纹 / 设备密码解锁**：用指纹或设备 PIN/图案/密码解锁（口令存于安卓 Keystore）；
  手动输 PIN 作为兜底。
- **导出 maFile**：账户菜单 → 将账户导出为未加密的 `<用户名>.maFile`，走系统分享。

### 变更
- **解锁近乎瞬时**：AVA 的 PIN 加密用极少 PBKDF2 轮数（6 位 PIN 受限于密钥空间，高轮数
  无实际安全意义）并避开慢路径；旧数据首次解锁时自动迁移。从约 15 秒降到几十毫秒。
- **无启动 logo / 白闪**：启动屏为 AVA 深色背景 + Android 12+ 透明 splash 图标。

## [v0.57] — 2026-06-30

### Added
- **Per-account Steam avatars**: each account's profile picture is fetched
  (public community XML, no API key), cached, and shown with the coloured
  initial as the fallback.

### Changed
- **Viewport-relative sizing** on phones — fonts, spacing, paddings and icons
  scale with the screen instead of fixed pixels (capped so large screens keep
  base sizes). The TOTP code scales to a proportion of the panel.
- **Tablet / foldable**: the two-pane layout keeps the v0.56 proportions
  (no upscaling, 240px account column).

—

### 新增
- **每个账户的 Steam 头像**：自动拉取账户资料头像（公开社区 XML，无需 API key）、
  缓存，并以彩色首字母作为回退。

### 变更
- 手机上**按视口相对缩放** —— 字号、间距、内边距、图标随屏幕缩放而非写死像素
  （大屏封顶、保持基准尺寸）；验证码按面板宽度的比例缩放。
- **平板 / 折叠屏**：两栏布局保持 v0.56 的比例（不放大、账户列 240px）。

## [v0.56] — 2026-06-30

Real-device validation of the full add-authenticator flow, including accounts
with no phone (email-based activation).

### Fixed
- **Add authenticator no longer hangs** on the working spinner: `_add()` reads
  localized strings and was invoked during `initState()`, which threw; it now
  runs after the first frame.
- **No-phone (email) activation**: when AddAuthenticator reports `confirm_type=3`
  (no phone), the activation code is emailed rather than texted, so finalize
  sends `validate_sms_code=false`. The finalize prompt and step label switch
  between "activation code from email" and "SMS code" accordingly.

—

对完整的「添加验证器」流程做真机验证，覆盖**无手机号**（邮箱激活）的账户。

### 修复
- **添加验证器不再卡在转圈**：`_add()` 会读取本地化文案，却在 `initState()` 阶段被调用而抛异常；现改为首帧之后再执行。
- **无手机（邮箱）激活**：当 AddAuthenticator 返回 `confirm_type=3`（无手机）时，激活码经**邮箱**而非短信下发，finalize 改为 `validate_sms_code=false`；激活提示与步骤标签也在「邮箱激活码 / 短信验证码」间自动切换。

## [v0.55] — 2026-06-30

Real-device validation of the networked flows against a live Steam account, plus
login UX and full localization. Login, session refresh and confirmations were
verified end-to-end.

### Added
- **Readable EResult names**: the full Steam `EResult` table (129 codes) — logs
  and errors now read e.g. `AccountLockedDown (73)` instead of a bare number.
- **Mobile-confirmation login**: when an account allows in-app approval, AVA
  polls immediately so you can tap **Allow** in the Steam mobile app instead of
  typing a code; the manual code field stays as an alternative.
- **CooldownButton**: submit buttons freeze for 1s after a press (counting down
  in 0.01s steps) to prevent accidental rapid re-submits.

### Fixed
- **Guard code** tolerates `DuplicateRequest (29)` (already accepted) and
  proceeds to polling — this had blocked password login.
- **Confirmations auto-refresh**: on `needauth` AVA exchanges the refresh token
  for a fresh access token and retries `getlist` once — no re-login needed.
- **Manual code stays available while polling** for an in-app approval (the
  waiting screen used to hide it); `AccountLockedDown (73)` / `RateLimitExceeded
  (84)` map to clear messages.

### Changed
- Client identity aligned with the official Steam mobile app (okhttp User-Agent,
  API headers, `gaming_device_type`) to reduce "unknown device" anti-fraud flags.
- All user-facing strings localized (English + 简体/繁體); error/result messages
  and the Debug log UI were previously hardcoded English.
- Bilingual `CHANGELOG.md`; GitHub Releases now show only the current version's
  changelog section.

—

在真实 Steam 账户上对联网流程做真机验证，并完善登录体验与全量本地化 —— 登录、
会话刷新、交易确认端到端跑通。

### 新增
- **可读的 EResult 名称**：完整 Steam `EResult` 表（129 个），日志与报错显示如
  `AccountLockedDown (73)`，不再是裸数字。
- **手机弹窗批准登录**：账户允许时立即轮询，可直接在 Steam App 点「允许」而无需
  输码；手动输码框作为备选保留。
- **冻结按钮**：提交后冻结 1 秒（每 0.01 秒步进倒数），防止手滑连点。

### 修复
- **令牌码**容忍 `DuplicateRequest (29)`（已被接受）并转入轮询 —— 此前会卡住密码登录。
- **确认自动刷新**：遇 `needauth` 时用 refresh token 换新 access token 并重试一次
  `getlist`，无需重新登录。
- 轮询等待 App 批准时**手动输码框保持可用**（此前等待页会隐藏它）；
  `AccountLockedDown (73)` / `RateLimitExceeded (84)` 映射为清晰提示。

### 变更
- 客户端标识对齐官方 Steam 手机 App（okhttp UA、API 头、`gaming_device_type`），
  降低合法登录被「陌生设备」风控误判。
- 所有用户可见文字本地化（英文 + 简体/繁體）；此前报错与调试日志界面为写死英文。
- 双语 `CHANGELOG.md`；GitHub Release 仅展示当前版本的变更小节。

## [v0.54] — 2026-06-30

Turned the remaining placeholder protocol code into real implementations,
following the SteamKit/SteamDatabase protobufs.

### Added
- **In-app Debug log** (Settings → Debug log): a copyable, scrollable trace of
  every Steam request/response (method, EResult, size) for diagnostics.

### Fixed
- **QR login** (`request_id` was read only on the credentials path) — scan-to
  -login no longer fails with `InvalidParam`.
- **`steamid` is `fixed64`** in several messages — added `fixed64` to the
  protobuf codec and corrected AddAuthenticator, FinalizeAddAuthenticator,
  UpdateAuthSessionWithSteamGuardCode, GenerateAccessTokenForApp and the
  mobile-confirmation message.
- **QR-login steamid** is taken from the JWT `sub` claim (it isn't in begin/poll).
- **AuthenticatorLinker** is now status-driven (no placeholder phone pre-check).

—

按 SteamKit/SteamDatabase protobuf 把剩余的占位协议代码全部转为正式实现。

### 新增
- **应用内调试日志**（设置 → 调试日志）：可滚动、可复制的 Steam 请求/响应追踪
  （方法、EResult、大小），便于诊断。

### 修复
- **扫码登录**：`request_id` 之前只在密码分支读取，导致扫码轮询报 `InvalidParam`，已修。
- 多处 **`steamid` 实为 `fixed64`** —— 给 protobuf 编解码器加 `fixed64`，并修正
  添加验证器、Finalize、令牌码提交、会话刷新及移动确认等消息。
- **扫码登录 steamid** 改从 JWT 的 `sub` 提取（begin/poll 不返回）。
- **添加验证器**改为 status 驱动（去掉占位的手机预检）。

## [v0.53]

- Refined the remaining screens to the design language; added the in-app DebugLog
  infrastructure (network request/response logging).
- 将其余界面精修至设计语言；加入应用内 DebugLog 基础设施（网络请求/响应日志）。

## [v0.52]

- Renamed the project to **AVA (AnotherVaporAuth)**; new app icon — Neon + Pixel
  variants, switchable in-app with the theme.
- 项目更名为 **AVA (AnotherVaporAuth)**；新应用图标 —— 霓虹 + 像素双变体，随主题切换。

## [v0.51]

- Bundled full CJK fonts (simplified + traditional, incl. rare username glyphs);
  removed the legacy C# implementation (kept on the `legacy` branch); bilingual README.
- 打包完整 CJK 字体（简体 + 繁体，含昵称生僻字）；移除旧版 C# 实现（保留在 `legacy`
  分支）；双语 README。

## [v0.50]

- Updated all dependencies to latest stable; bundled fonts (no runtime download);
  switched to `file_selector`; CI Linux build uses Node 24.
- 所有依赖更新至最新稳定版；字体打包（运行时不下载）；改用 `file_selector`；
  CI Linux 构建使用 Node 24。

## [v0.49]

- GitHub Actions: analyze/test on push, tag-driven releases (Android + Linux + Windows).
- GitHub Actions：推送即 analyze/test，标签触发发布（Android + Linux + Windows）。

## [0.1 – 0.48] — Flutter rewrite · Flutter 重写

- Complete rewrite from the legacy .NET WinForms app to **Flutter** (Windows /
  macOS / Linux / Android from one codebase). Byte-compatible `.maFile` crypto
  (PBKDF2 50k/SHA1 + AES-256-CBC), TOTP, confirmations (native JSON, batch),
  login (password + QR), add authenticator, two themes (Neon + Pixel), i18n.
- 从旧版 .NET WinForms 完整重写为 **Flutter**（一套代码覆盖 Windows / macOS /
  Linux / Android）。字节级兼容的 `.maFile` 加密（PBKDF2 50k/SHA1 + AES-256-CBC）、
  TOTP、交易确认（原生 JSON、批量）、登录（密码 + 扫码）、添加验证器、双主题
  （霓虹 + 像素）、多语言。

[v0.58]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.58
[v0.57]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.57
[v0.56]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.56
[v0.55]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.55
[v0.54]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.54
[v0.53]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.53
[v0.52]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.52
[v0.51]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.51
[v0.50]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.50
[v0.49]: https://github.com/freefrank/AnotherVaporAuth/releases/tag/v0.49
