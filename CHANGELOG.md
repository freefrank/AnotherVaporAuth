# Changelog · 更新日志

All notable changes to **AVA (AnotherVaporAuth)**. Each version has an English
block followed by a 中文 block. The format follows
[Keep a Changelog](https://keepachangelog.com/); `v<MAJOR.MINOR>` tags trigger
automated releases.

## [v1.2.0-beta] — 2026-08-12

### Added
- **Sync your accounts between devices, through a server you control
  (WebDAV).** Settings → Sync: point AVA at a Nextcloud / Jianguoyun (坚果云)
  / NAS folder, set a sync passphrase, and every device connected to that
  folder keeps the same account library — additions, changes and deletions
  included. Highlights, because this feature handles your most sensitive
  data:
  - **Everything is encrypted on the device before upload**, with a
    passphrase that never leaves your devices. The server operator sees
    ciphertext. There is no reset if you lose it — that is the deal.
  - **The remote folder is a standard SDA encrypted folder.** SDA,
    steamguard-cli and AVA's own folder import can all read it: your cloud
    copy doubles as a portable backup, not a lock-in.
  - **Steam sessions never sync; saved account passwords do** (optional,
    on by default). A new device signs each account in by itself the first
    time you use it.
  - **Nothing is ever silently destroyed.** Anything sync removes or
    replaces — a deletion arriving from another device, either side of a
    conflict you resolve — is kept encrypted in a local sync trash for 30
    days, restorable in two taps. Conflicts are decided by you, per
    account, never by a clock.
  - Plain HTTP is refused for public hosts unless you explicitly type
    `http://` and hold-to-confirm the risk; self-signed certificates are
    pinned by fingerprint after you compare them.
  - This is a **beta**: the engine is covered by 49 tests, but real-world
    WebDAV servers vary. Keep your maFile backups (you should anyway).

### 新增
- **账户可以在多台设备间同步了，走你自己掌控的服务器（WebDAV）。**
  设置 → 同步：填上 Nextcloud / 坚果云 / NAS 的文件夹，设一个同步口令，
  连着同一个文件夹的每台设备就保持同一份账户库——增、改、删都会传播。
  这个功能经手的是你最敏感的数据，所以：
  - **所有数据在设备上加密后才上传**，口令绝不离开你的设备，服务器
    运营者只能看到密文。口令丢失无法重置——这是明码标价的代价。
  - **远端文件夹就是标准的 SDA 加密文件夹**，SDA、steamguard-cli 和
    AVA 自己的文件夹导入都能读：云端副本同时是一份可带走的备份，
    不是锁进 AVA 的私有格式。
  - **Steam 会话绝不同步；已保存的账户密码会同步**（可选，默认开）。
    新设备上每个账户首次使用时会自行重新登录。
  - **任何东西都不会被静默销毁。** 被同步删除或替换的账户——别的设备
    传来的删除、你解决冲突时舍弃的那一侧——都会加密存入本地同步
    回收站保留 30 天，两步即可恢复。冲突逐账户由你决定，绝不由时钟
    决定。
  - 公网明文 HTTP 默认拒绝，除非亲手输入 `http://` 并长按确认风险；
    自签名证书按指纹逐台钉住。
  - 这是 **beta**：引擎有 49 个测试盯着，但现实中的 WebDAV 服务器
    千奇百怪。maFile 备份照常留着（本来也该留）。

—

## [v1.1.1] — 2026-08-12

### Fixed
- **The desktop window now opens centered on the screen you are working on,
  not in the top-left corner.** The monitor that holds your mouse cursor is
  the one the window opens on, sized for that monitor's DPI and kept inside
  its work area, so the title bar cannot start half off-screen. On virtual
  desktops it opens on the active one, as new windows always do. One caveat
  on Linux: under Wayland the compositor alone decides window placement —
  X11 sessions center as described.

### 修复
- **桌面版窗口现在会在你正在用的那块屏幕上居中打开,而不是缩在左上角。**
  以鼠标光标所在的显示器为准,按该显示器的 DPI 取尺寸,并保证不超出其
  工作区,标题栏不会再有一半探出屏幕外。多虚拟桌面下与所有新窗口一样,
  开在当前活动桌面。Linux 有一处例外:Wayland 会话下窗口位置由合成器
  全权决定,X11 会话按上述行为居中。

—

## [v1.1.0] — 2026-08-11

### Added
- **Import a whole Steam Desktop Authenticator folder, encrypted ones
  included.** Previously only a single *unencrypted* `.maFile` could be
  imported — so anyone who had turned on SDA's encryption, which SDA's own
  README calls "highly recommended", could not migrate at all. Home → Import an
  SDA folder: select `manifest.json` together with your `.maFile` files, enter
  the passphrase you set in SDA, and every account comes across at once.
  - `manifest.json` is required, and not out of convenience: when SDA
    encryption is on, each account's salt and IV live in its manifest row, not
    in the `.maFile`. A lone encrypted maFile cannot be decrypted by anything.
  - A wrong passphrase says so, instead of reporting your files as corrupt.
  - Accounts already on this device are skipped rather than overwritten, and
    named in the summary. Import that one file on its own to replace it.

### 新增
- **可以整个导入 Steam Desktop Authenticator 的文件夹了,加密的也能导。**
  此前只能导入单个**未加密**的 `.maFile`——也就是说,凡是在 SDA 里开了加密的
  人(而 SDA 自己的 README 把加密称为「强烈推荐」)根本迁移不过来。首页 →
  导入 SDA 文件夹:把 `manifest.json` 和那些 `.maFile` 一起选中,输入当初在
  SDA 里设的口令,所有账户一次性搬过来。
  - **必须选上 `manifest.json`**,这不是图省事:开了加密之后,每个账户的 salt
    与 IV 存在 manifest 的对应行里,不在 `.maFile` 内部。孤立的一个加密 maFile
    任何工具都解不开。
  - 口令错了会直接说口令错,而不是报告你的文件损坏。
  - 本机已有的账户会被跳过而不是覆盖,并在结果里列出名字。要替换就单独导入
    那一个文件。

—

## [v1.0.1] — 2026-08-07

### Added
- **Five more languages: 繁體中文, Deutsch, Français, Español, Русский.**
  Each is translated from English rather than machine-converted — the
  Traditional Chinese uses Taiwan vocabulary, not a character swap of the
  Simplified text. Pick one in Settings → Language; the choice now survives a
  restart correctly, which it did not for Traditional Chinese.

### Changed
- **The privacy notice on first run was wrong, and has been rewritten.** It
  said AVA "has no backend of its own" and "connects only to Valve's Steam
  servers". Neither was true: there are two services the developer runs — Pro
  entitlement checks, and feedback delivery when you press send — and the Play
  build shows ads on the free tier. **Nothing about what the app does has
  changed; only the description of it.** All of this was already spelled out
  in the full Privacy Policy, which the notice now matches.
- **If you accepted the old notice, AVA asks once more.** You get a short
  explanation of what was wrong rather than the first-run welcome screen.
  Consent is now tracked per revision, so a future change to the notice can
  ask again instead of quietly relying on agreement to different wording.
- **Agree stays disabled until you have scrolled to the end** of the notice.

### Fixed
- **Uninstalling the Windows build no longer removes files it did not
  install.** It used to delete the entire install folder, so anyone who had
  pointed the installer at an existing folder — Documents, say — lost that
  folder's contents. It now removes only what it wrote, keeps everything else,
  and refuses to install into a drive root, your home folder, or any folder
  that already has unrelated files in it.
- **Redeeming a code too many times now says so** instead of reporting the
  code as invalid.
- **The Windows portable build is 31% smaller** (24.9 MB → 17.2 MB). It is now
  packed with NSIS instead of a closed-source tool that had to be downloaded
  at build time. Recorded here rather than under v1.1.0 because this is the
  binary that actually shipped in the v1.0.1 release, rebuilt from `main` and
  uploaded shortly after the tag.

—

### 新增
- **新增五种语言:繁體中文、Deutsch、Français、Español、Русский。**
  都是从英文翻译的,不是机器转换——繁體中文用的是台湾用语,而不是把简体做
  字符替换。在「设置 → 语言」里选;语言选择现在能正确扛过重启,此前繁體中文
  是不行的。

### 变更
- **首次启动的隐私说明写错了,已重写。** 它此前写着 AVA「没有自己的后端」
  「只连接 Valve 的 Steam 服务器」。两句都不成立:开发者自己运行着两个服务
  ——Pro 权益校验,以及你按下发送时的反馈投递——Play 版免费档还会显示广告。
  **应用的行为没有任何变化,变的只是对它的描述。** 这些内容在完整的隐私政策
  里本来就写着,现在是说明追上了政策。
- **同意过旧说明的用户会被再问一次。** 看到的是一段「哪里写错了」的简短说明,
  而不是首次启动的欢迎页。同意状态现在按版本记录,所以以后再改说明可以重新
  征求,而不是默默沿用对另一段文字的同意。
- **必须滑到说明末尾,「同意」按钮才可点。**

### 修复
- **Windows 便携版体积小了 31%**(24.9 MB → 17.2 MB)。改用 NSIS 打包,不再
  依赖一个每次构建都要现下载的闭源工具。记在这一版而不是 v1.1.0,因为它就是
  v1.0.1 发行页上实际发出去的那个文件——在打标签之后由 `main` 重新构建并补传。
- **卸载 Windows 版不会再删掉不是它装的文件。** 此前是整个安装目录递归删除,
  所以把安装路径指到已有文件夹(比如「文档」)的人,卸载时会连里面的东西一起
  失去。现在只删自己写入的文件,其余原样保留;并且拒绝安装到盘符根目录、用户
  主目录,或任何已经有别的文件的文件夹。
- **兑换激活码次数过多时会如实说明**,而不是报告激活码无效。

## [v1.0.0] — 2026-07-30

### Added
- **Block screenshots (Android, off by default).** A new switch in Settings
  keeps AVA out of screenshots, screen recordings and the recent-apps
  preview. It stays off unless you turn it on, because the same flag also
  blanks the window while you are sharing your screen and stops you attaching
  a screenshot to a feedback report — a fair trade for some people, not for
  everyone.

### Security
- **Redeeming a code is now rate-limited.** Repeated attempts against the
  beta-code and Afdian order endpoints are throttled per address, and the app
  says "too many attempts, wait a minute" instead of reporting a bad code. A
  lifetime beta code could previously be guessed at whatever rate a script
  could manage.
- **A misconfiguration can no longer weaken Google sign-in.** The server ties
  each sign-in token to AVA's own OAuth client; that check used to be skipped
  — rather than refusing the sign-in — if the client id ever went missing from
  the deployment.

—

### 新增
- **禁止截屏(Android,默认关)。** 设置里新增一个开关,打开后 AVA 不会出现在
  截屏、录屏和最近任务预览里。默认不开,因为同一个标志也会让你投屏时窗口变黑、
  没法再截图附到反馈里——有人觉得值,有人不觉得,所以交给你决定。

### 安全
- **兑换激活码加了频率限制。** 内测码与爱发电订单两个接口按来源地址限流,应用
  会提示「尝试次数过多,请稍等一分钟」,而不是报激活码无效。此前一个终身内测码
  可以被脚本以任意速度猜。
- **配置失误不再能削弱 Google 登录校验。** 服务端会把每个登录令牌绑定到 AVA
  自己的 OAuth 客户端;这项检查以前会在客户端 id 从部署里缺失时**跳过**,而不是
  拒绝登录。

## [v0.99.0] — 2026-07-30

### Added
- **AVA Pro subscription on the Google Play version.** Signing in and
  subscribing were previously answered with "not available in this build";
  the Play build can now reach them. The lifetime beta codes and the Afdian
  route are unchanged, and nothing about your Steam accounts depends on any
  of it.

—

### 新增
- **Google Play 版的 AVA Pro 订阅。** 登录与订阅此前一律回「当前构建尚未开通
  此功能」,现在 Play 版可以走通这条路。终身内测码与爱发电通道不变,Steam
  账户相关的功能与这些都无关。

## [v0.94.0] — 2026-07-30

### Added
- **Redeem a Steam key from the account menu.** Paste or type a product key,
  confirm, and it's activated on that account — the products it grants are
  listed straight back to you. Steam's own rejection reasons are spelled out
  (mistyped code, already owned, already used, wrong country, needs the base
  game, rate-limited) instead of a bare error number. Activation is permanent,
  so it always asks once before submitting and never retries a key by itself.

### Changed
- **The long-press account menu is shorter.** It used to repeat what the swipe
  gestures already do — to-dos (swipe right), refresh / export / remove (swipe
  left) — which buried the entries that have no other way in. It now lists only
  Market, Family group, Devices, and Redeem key. Nothing was lost: the swipes
  are unchanged, and the desktop right-click menu still carries every action.

### Fixed
- **Nothing hides under the system bars or the screen's rounded corners any
  more.** Android 15 and 16 draw every app edge-to-edge and can't be opted out
  of, so scrolled content — the top of a long form, the last card in a list —
  was ending up behind the status bar or the gesture pill, and on curved
  displays the settings button and the skin's corner decorations were clipped
  by the corner itself. AVA now asks Android for the display's actual corner
  radius, re-reading it when a foldable is unfolded.
- **A feedback report that won't send now says why.** "Check your network" was
  shown for every failure, including ones where the service had answered and
  explained itself, and nothing was written to the debug log to work from.
- **An error that ends in a Steam redirect now names where it went** instead of
  showing a bare status code — on every screen that talks to Steam.

—

### 新增
- **在账户菜单里兑换 Steam 密钥。** 粘贴或输入产品密钥,确认后即激活到该账户,
  并直接列出到手的产品。Steam 的拒绝理由会写成人话(输错、已拥有、已被使用、
  地区不符、需要本体游戏、被限流),而不是甩一个错误码。激活不可撤销,因此
  提交前必定二次确认,失败也绝不自动重试。

### 变更
- **长按账户菜单变短了。** 它原本重复了滑动手势已有的入口——待办(右滑)、
  刷新 / 导出 / 删除(左滑)——把只有这里才能进的功能埋在了下面。现在只列
  市场、家庭组、设备、兑换密钥。功能一个没少:手势照旧,桌面右键菜单仍是全套。

### 修复
- **内容不再藏到系统栏或屏幕圆角底下。** Android 15 / 16 强制全屏边到边且无法
  关闭,导致滚动后的内容——长表单的顶部、列表的最后一张卡片——被状态栏或手势
  小横条盖住;曲面屏上设置按钮与皮肤的四角装饰还会被圆角本身切掉。现在 AVA 会
  向 Android 查询屏幕的真实圆角半径,折叠屏展开后会重新查询。
- **反馈发不出去时会说明原因了。** 以前任何失败都只显示「请检查网络」,包括
  服务端已经答复并给出原因的情况,而且调试日志里什么都不留,无从排查。
- **被 Steam 重定向而失败的请求会写明跳去了哪里**,不再只显示一个状态码——
  所有与 Steam 通信的页面都适用。

## [v0.92.0] — 2026-07-18

### Added
- **Device management.** See every device and browser session signed into your
  Steam account — platform, rough location, and last activity — and remotely
  sign out any of them. The current device is marked and can't sign itself out.
  Open it from an account's menu. (The remote sign-out reproduces exactly what
  Steam's own mobile app does.)

### Changed
- **The account menu is now touch-first.** Long-press an account to open it (it
  used to be desktop right-click only, so on a phone the market / family /
  devices entries had no way in), and the menu appears centered on screen with
  larger rows instead of a desktop-style popup. Holding an account now also
  scales the card and gives a haptic tap so the long-press is discoverable.
- **Family group invites moved.** They now live in the family group screen
  (reached from the account menu) instead of a third tab in the to-do center,
  which drops to two tabs (Confirmations / Trade offers). Discovering,
  pre-checking, and joining an invite work exactly as before.

—

### 新增
- **设备管理。** 查看登录了你 Steam 账户的所有设备与浏览器会话——平台、大致
  地点、最近活跃时间——并可远程注销其中任意一台。本机会被标记且不能自注销。
  从账户菜单进入。(远程注销复刻的正是 Steam 官方手机 App 的行为。)

### 变更
- **账户菜单改为触屏优先。** 长按账户即可打开(以前只有桌面右键能开,手机上
  市场 / 家庭组 / 设备等入口无从进入),菜单改为**居中显示**、行更大,不再是
  桌面风格的贴边弹出。长按时卡片会缩放并伴一次轻震动,让"可长按"更易被发现。
- **家庭组邀请挪了位置。** 现在收进**家庭组页面**(从账户菜单进),不再占用
  待办中心的第三个页签——待办中心因此降为两页签(确认 / 报价)。邀请的发现、
  预检、加入流程与以前完全一致。

## [v0.91.2] — 2026-07-17

### Changed
- About screen wording: AVA is now described as an independent project built
  with Flutter, inspired by the classic Steam Desktop Authenticator — not a
  "rewrite" of it. AVA shares no code with SDA and only keeps its `.maFile`
  format compatible for easy migration.

—

### 变更
- 关于页文案:AVA 现定位为受老牌工具 Steam Desktop Authenticator 启发、用
  Flutter 打造的独立项目,不再表述为对它的"重写"。AVA 与 SDA 不共享任何代码,
  仅保持 `.maFile` 格式兼容以便迁移。

## [v0.91.1] — 2026-07-17

### Added
- **Importing a maFile for an account you already have** now asks whether to
  overwrite it, with an honest description of what survives the merge.

### Changed
- **Hold-to-confirm now responds the instant you press.** Holding to accept a
  trade, join a family group, or confirm a mobile request used to look dead
  for the first moment — nothing visibly moved, so it felt like a broken
  button. Now the button grows slightly and its progress ring jumps straight
  to the halfway mark the moment you touch it, then fills the rest as you
  hold. The hold itself is exactly as long as before — only the feedback is
  faster.

### Fixed

Three rounds of adversarial audit landed in this release (51 + 34 + 19
candidate findings, each independently re-verified before being acted on).
Most of the outcome is invisible hardening; these are the parts you would
have noticed.

- **Renewed sign-in tokens now survive a restart.** Five screens "saved" a
  refreshed session by writing only the account index, so the new token died
  with the process and every launch repeated the sign-in dance.
- **An expired session no longer disguises itself as something else.** Community
  requests ignored the HTTP status, so a redirect to Steam's login page or an
  empty 401 decoded as an empty success: cancelling a listing claimed to work
  when it hadn't, and confirmations showed the alarming "wrong secret" message.
  Authentication failures now lead to the sign-in prompt instead.
- **Comma decimals no longer list an item at 100× the price.** The sell sheet
  silently deleted `,`, turning "1,50" into "150". Comma is now accepted as a
  decimal separator, and ambiguous thousands formatting is rejected outright.
- **Pro no longer lapses to free when our signing key rotates.** An entitlement
  that fails local verification is re-checked with the server and only discarded
  on a definitive rejection. Pro also expires on time during long sessions, and
  desktop builds no longer report themselves as Android devices.
- **Moving an authenticator to this device can no longer lose the new secret.**
  Leaving the screen mid-request could discard the only copy of the
  freshly-issued secret — while the old authenticator was already dead. It is
  now saved no matter what, and a failed save shows a recovery screen with the
  new revocation code and secret in full, which system-back cannot dismiss.
- **A lost account index is recoverable.** It used to dead-end on a raw error
  screen; it now offers retry, a guarded reset, or an evidence-based rebuild.
  Saving two accounts at once can no longer delete both encrypted copies, and
  entries that fail to decrypt during an upgrade are preserved instead of
  dropped.
- **Batch listing tells the truth** about partial success, a session that
  expires mid-batch, and partially completed auto-confirmations.
- **Debug logs no longer leak roughly a third of Steam's secrets** — redaction
  missed padded base64 containing `/`.
- **A Steam password you deleted stays deleted.** A leftover copy from the
  pre-vault keystore could bring it back.

—

### 新增
- **导入一个你已经添加过的账户的 maFile** 时会先问你是否覆盖,并如实说明
  合并后哪些信息会保留。

### 变更
- **长按确认现在一按就有反应。** 长按接受交易、加入家庭组或确认手机请求时,
  最初一刻按钮毫无动静,让人以为按钮坏了。现在手指一碰,按钮会微微放大、
  进度环立刻跳到一半,余下部分随长按继续填满。长按时长与以前完全一致——
  只是反馈更快了。

### 修复

本版落地了三轮对抗式审计(候选发现 51 + 34 + 19 条,每条都经独立复核后才
采纳)。绝大部分成果是你看不见的加固,下面这些是你**能感觉到**的部分。

- **续期后的登录令牌现在能扛过重启了。** 有五处界面"保存"刷新后的会话时,
  实际只写了账户索引——新令牌随进程一起消失,于是每次启动都要重登一遍。
- **会话过期不再伪装成别的错误。** 社区请求此前无视 HTTP 状态码,跳转到
  Steam 登录页或空的 401 都会被解析成"空的成功":取消挂单明明没成功却提示
  成功,确认页则弹出吓人的"密钥错误"。现在认证失败会直接引导你重新登录。
- **用逗号做小数点不会再把商品挂成 100 倍价格。** 卖出页此前会静默删掉
  `,`,"1,50" 就变成了 "150"。现在逗号可作小数分隔符,写法有歧义的千分位
  会被直接拒绝。
- **签名密钥轮换不会再把 Pro 打回免费。** 本地验签失败的权益凭证会回服务器
  复核,只有明确被拒才丢弃。长时间挂着不关时 Pro 也会按时到期,桌面版不再
  把自己报成安卓设备。
- **把验证器移到本设备不会再弄丢新密钥了。** 请求进行到一半时退出页面,可能
  把刚换发的密钥的唯一副本丢掉——而此时旧验证器已经作废。现在无论如何都会
  先存盘,存盘失败会摊出完整的新撤销代码与密钥,该页面按系统返回键也关不掉。
- **账户索引丢了也能救回来。** 以前是一个死胡同般的原始报错页,现在提供重试、
  受控重置、以及基于现有证据的重建。同时,两个账户同时保存不会再把两份加密
  数据都删掉;升级过程中解密失败的条目会被原样保留而不是丢弃。
- **批量挂单会如实汇报**部分成功、中途会话过期、以及只完成了一部分的自动确认。
- **调试日志不再泄漏大约三分之一的 Steam 密钥**——此前脱敏漏掉了含 `/` 的
  补位 base64。
- **你删掉的 Steam 密码不会再自己回来。** 旧密钥库里残留的一份副本会让它复活。

## [v0.91.0] — 2026-07-16

### Added
- **Move an existing authenticator to this device.** Signing in to an account
  that already has a Steam Guard authenticator elsewhere no longer dead-ends
  in "go remove it on the website first". AVA can now move it over directly:
  Steam emails a code, you enter it, done — and unlike removing the
  authenticator on the website, this incurs **no 15-day trade hold**. The old
  phone's authenticator stops working the moment you confirm, and your
  revocation code is replaced by a new one, so write the new one down. The
  old "remove it elsewhere" instructions are still there as a fallback for
  accounts whose email is out of reach.

—

### 新增
- **把已有的验证器移到本设备。** 登录一个在别处已绑定 Steam 令牌的账户时,
  不再只能卡在"请先去网页移除"。AVA 现在可以直接把它移过来:Steam 发一封
  带验证码的邮件,输入即完成——而且与在网页上移除验证器不同,这条路
  **不会挂 15 天交易冷却**。确认的瞬间旧手机上的验证器就会失效,撤销代码
  (R 码)也会换成新的,请把新的记下来。原来那套"去别处移除"的引导仍然保留,
  供邮箱无法访问的账户兜底。

## [v0.90.1] — 2026-07-16

### Fixed
- **Play build crashed at launch** (release-only): R8 stripped a class the
  ads dependency creates reflectively at process start. The v0.90.0
  internal-testing build is superseded — update immediately.
- **Launch crash-loop on ColorOS/OPPO devices.** Two separate mechanisms
  rewrote the app's own component states while it was in the foreground
  (WorkManager's first run after every install, and the launcher-icon
  switcher reacting to the new skin gating), and ColorOS force-stops an app
  whose components change — reliably killing AVA on the unlock screen.
  WorkManager's startup auto-init is removed and launcher-icon switching is
  retired entirely.
- **Neon/Pixel skins now actually fall back to the plain look** for free
  users: the 0.90.0 paywall gated the skin effects but missed the theme
  colors, so a previously selected Pro skin kept rendering.

### Changed
- The home-screen icon no longer follows the skin; it stays as it is. The
  feature will only return with a mechanism that cannot toggle components
  while the app is running.

—

### 修复
- **Play 版启动即闪退**(仅 release 构建):R8 剥除了广告依赖在进程启动时
  反射创建的类。0.90.0 内测包已作废,请立即更新。
- **ColorOS/OPPO 设备上的启动闪退循环。** 两个独立机制会在应用前台运行时
  改写自身组件状态(WorkManager 每次安装后的首次运行,以及桌面图标切换
  对新皮肤门禁的反应),而 ColorOS 会对组件变更的应用就地强停——AVA 在
  解锁页被稳定杀死。现已移除 WorkManager 的启动自动初始化,并整体下线
  图标切换功能。
- **Neon / Pixel 皮肤现在会真正回落到黑/白基础外观**:0.90.0 的付费墙拦住了
  皮肤特效层却漏了主题配色层,已选过 Pro 皮肤的免费用户此前仍会渲染原皮肤。

### 变更
- 桌面图标不再跟随皮肤变化,保持现状。该功能只会在找到"运行中绝不切换
  组件"的实现方式后回归。

## [v0.90.0] — 2026-07-16

### Added
- **AVA Pro.** A subscription now funds development — and the promise from
  the beta recruitment post stands: **codes, confirmations, login approvals
  and maFile import/export stay free forever**, and every beta tester gets
  lifetime Pro (redeem codes go out separately). Pro currently covers the
  Neon & Pixel theme packs (new installs default to the plain black/white
  look) and, on the Play build, removes the banner ad; cloud sync and trade
  notifications will join later. Unlocking is per channel: Google Play
  subscription at $0.99/month with a rewarded-video option (one ad = 3-day
  VIP), or Afdian at ¥5/month for the direct build — enter the order number
  in the app, no account needed. One subscription activates one device per
  platform class (phone / Windows / Linux / macOS). The cn APK contains no
  Google ads/billing code at all.
- **Settings → AVA Pro** shows your status and hosts restore / unlock entry
  points.

### Changed
- If you were using the Neon or Pixel skin, it is now a Pro perk: the app
  falls back to the plain look (your dark/light preference is kept, and the
  selection returns the moment Pro unlocks). A one-time notice explains this
  after upgrading.

—

### 新增
- **AVA Pro。** 订阅制正式落地——招募帖的承诺不变:**令牌验证码、交易确认、
  登录批准、maFile 导入导出永久免费**,内测用户人人终身 Pro(兑换码将另行
  发放)。Pro 当前包含 Neon 与 Pixel 主题包(新安装默认黑/白基础外观),
  Play 版另享去横幅广告;云同步、交易通知等在线功能后续加入。解锁按渠道:
  Google Play 订阅 $0.99/月,或看一条激励视频得 3 天 VIP;国内直发版走爱发电
  ¥5/月,在 app 内输入订单号即可,无需注册账户。一份订阅在手机 / Windows /
  Linux / macOS 四类端各可激活一台设备。cn 版 APK 完全不含 Google 广告与
  计费代码。
- **设置 → AVA Pro**:查看状态、恢复购买、各类解锁入口。

### 变更
- 正在使用 Neon / Pixel 皮肤的用户:皮肤已成为 Pro 权益,应用回落到黑/白
  基础外观(深浅色偏好保留,解锁 Pro 后所选皮肤立即恢复),升级后会有一次性
  说明提示。

## [v0.84.0] — 2026-07-15

### Added
- **Text size setting.** Settings → Text size: Small (the previous default),
  Medium, Large. The chosen step applies on top of your system font size.

—

### 新增
- **字号设置。** 设置 → 字号:小(即此前的默认大小)、中、大,
  所选档位在系统字体大小的基础上叠加。

## [v0.83.0] — 2026-07-15

### Changed
- **Two distribution channels.** Android now builds as two flavors under the
  same package name: `play` (Google Play) and `cn` (direct APK on GitHub
  Releases). Groundwork for the upcoming Pro subscription: Play-only
  dependencies (billing, ads) will live in the play flavor only — the cn
  build will never contain them. No user-visible changes in this release.

—

### 变更
- **双分发渠道。** Android 现以同一包名构建两个 flavor:`play`(Google
  Play)与 `cn`(GitHub Release 直发 APK)。为后续 Pro 订阅铺路:计费、
  广告等 Play 专属依赖只会进 play flavor,cn 包永远不含。本版无用户可见变化。

## [v0.82.0] — 2026-07-15

### Added
- **Steam Family groups.** The Pending center gains an **Invites** tab:
  family-group invites are discovered automatically, each card runs pre-join
  checks where Steam allows it (wallet region, usual IP — a region mismatch
  disables joining) and always warns about the 1-year switching cooldown.
  Joining is the same hold-to-confirm gesture as everywhere else; AVA then
  jumps to the Confirmations tab where the family-join confirmation (properly
  labeled since 0.81.0) is waiting. A read-only **family group page** (account
  menu → Family group) shows members with roles, slot usage and the slot
  cooldown. Built on Valve's own client API surface; treat as experimental
  until it has seen more real-world accounts.

### Fixed
- API errors now show a short reason (e.g. "HTTP 405") instead of a raw
  exception dump on the Pending tabs and the family page.

—

### 新增
- **Steam 家庭组。** 待办中心新增**邀请**页签：自动发现家庭组邀请，每张邀请卡
  在 Steam 允许的范围内做加入前预检（钱包地区、常用 IP——地区不符会禁用加入），
  并始终提示一年冷却。加入使用与全应用一致的长按确认手势；随后 AVA 自动跳到
  确认页签，那里等着的正是 0.81.0 起有了专属标签的"家庭组邀请"确认。新增只读
  的**家庭组信息页**（账户菜单 → 家庭组）：成员及角色、空位占用、空位冷却。
  基于 Valve 官方客户端的接口面构建；在经历更多真实账户前请视为实验性功能。

### 修复
- 待办页签与家庭组页的接口错误现在显示简短原因（如 "HTTP 405"），
  不再输出原始异常串。

## [v0.81.0] — 2026-07-15

### Added
- **Trade offers, in the app.** The confirmations screen is now a tabbed
  **Pending center** (swipe right on an account, as before): alongside
  mobileconf confirmations there is a **Trade offers** tab — received / sent /
  history segments, expandable cards showing both sides' items (rarity-colored
  borders, disk-cached icons), and explicit banners for gift offers ("you give
  nothing"), one-sided giveaways and escrow holds. Accept an offer and AVA
  jumps straight to the Confirmations tab with the fresh mobileconf entry
  loaded; decline/cancel works from the card. Reads use Valve's documented
  IEconService API; accepting only ever reports success on Steam's positive
  confirmation.
- **Hold-to-confirm, everywhere.** Irreversible accepts — a trade offer, a
  single confirmation's ✓, "Accept all" — now share one control: press and
  hold while a progress ring fills, with haptic ticks that speed up until the
  action commits ("Accept all" no longer needs its extra dialog; the hold *is*
  the second confirmation). Two new Settings toggles: **Hold to confirm**
  (off = single tap, batch actions keep the dialog) and **Haptic feedback**.
  Screen-reader users get an equivalent activation path, with batch accepts
  still routed through the dialog.
- **Confirmation types, properly labeled.** Steam Family invites, web API key
  creation, phone-number changes and account recovery now show their own
  labels and warning colors instead of a generic "Confirm" chip.

### Fixed
- Rapid toggling of two settings no longer loses one of the writes
  (`app_settings.json` updates are serialized).

—

### 新增
- **应用内交易报价。** 确认页升级为带页签的**待办中心**（入口不变：账户右
  滑）：mobileconf 确认旁新增**报价**页签——收到 / 发出 / 历史三个分段，
  可展开卡片显示双方物品（稀有度边框、图标走磁盘缓存），并对赠送（"你无
  需给出物品"）、只给不收、暂挂交付显示醒目警示条。接受报价后 AVA 直接
  跳到确认页签并加载新出现的 mobileconf 确认；拒绝/取消在卡片上就地完成。
  读取走 Valve 文档化的 IEconService API；接受只在收到 Steam 的正向确认
  时才报告成功。
- **全局统一的长按确认。** 所有不可逆的接受操作——交易报价、单条确认的
  ✓、"全部接受"——共用同一个控件：按住不放，进度环填满、震动节奏逐渐加
  快直到操作生效（"全部接受"不再额外弹窗，长按本身就是二次确认）。设置
  新增两个开关：**长按确认**（关闭后单击生效，批量操作保留弹窗）与
  **震动反馈**。读屏用户有等效的激活路径，批量接受仍会经过弹窗确认。
- **确认类型有了明确标签。** 家庭组邀请、Web API 密钥创建、更换手机号、
  账户恢复不再显示为笼统的"确认"，而是各自的标签与警示配色。

### 修复
- 快速连拨两个设置开关不再丢失其中一个的写入（`app_settings.json`
  更新已串行化）。

## [v0.80.1] — 2026-07-06

### Fixed
- **A rejected confirmation list no longer looks like "no pending trades".**
  When Steam rejects `mobileconf` at the signature level (maFile doesn't match
  the authenticator currently on the account — common with purchased accounts —
  or heavy clock drift), the confirmations screen now explains the likely cause
  and the way out, instead of silently showing an empty list.
- **maFiles without a `device_id` can confirm again.** An empty device id is
  always rejected by Steam; a stable SteamID-derived one is now used instead.

—

### 修复
- **确认列表被 Steam 拒绝时不再伪装成“暂无待确认”。** 当 `mobileconf`
  在签名层被拒（maFile 与账户当前验证器不匹配——购入账户较常见——或设备
  时间偏差过大），确认页现在会说明可能原因与解决途径，而不是静默显示空列表。
- **缺少 `device_id` 的 maFile 恢复可确认。** 空 device id 必被 Steam 拒绝；
  现改用由 SteamID 派生的稳定值兜底。

## [v0.80.0] — 2026-07-06

### Added
- **Activate the session right after importing a maFile.** Imports now try to
  renew the file's Steam session silently; when it's already dead (the usual
  case for files from another device) AVA offers to sign in on the spot —
  username prefilled, Steam Guard code filled in automatically — instead of
  leaving you to find the session-refresh entry on your own.

—

### 新增
- **导入 maFile 后顺势激活会话。** 导入时会先尝试静默续期文件里的 Steam
  会话;若已失效(来自其他设备的文件几乎都是),会当场询问是否登录——
  用户名已预填、令牌验证码自动填写——不再需要自己去找“会话刷新”入口。

## [v0.79.0] — 2026-07-06

### Fixed
- **QR sign-in: half of all login QR codes were rejected as "not a Steam QR
  code".** Steam's `client_id` is a random uint64; values above 2⁶³−1 (about
  half of them) failed Dart's signed-int parsing. They are now parsed as full
  64-bit values.
- **Blank screen after scanning.** The scanner fired repeatedly for the same
  code during the page-close animation, popping extra routes off the
  navigator; it now latches on the first detection.
- **Approving a login with an expired session no longer fails.** Steam access
  tokens live ~24 h; the QR-approval flow now renews a stale token first
  (refresh token, then headless re-login) — same as the pending-login check —
  and clearly says "session expired, please sign in again" if neither works.
- **Silent fake success on rejected approvals.** A Steam reply with no
  `x-eresult` header and a non-2xx status (e.g. a bare 401 for an expired
  token) was treated as OK, showing "approved" while the PC kept waiting; it
  now surfaces as an error.

—

### 修复
- **扫码登录:约一半的登录二维码被误判为“这不是 Steam 二维码”。**
  Steam 的 `client_id` 是随机 uint64,超过 2⁶³−1 的值(约占一半)在 Dart
  有符号整数解析下失败;现按完整 64 位解析。
- **扫码后出现空白页。** 关闭扫码页的动画期间,同一个二维码会被重复识别,
  多余的回调把导航栈里下面的页面也弹掉了;现在只响应第一次识别。
- **会话过期时无法批准登录。** Steam 的 access token 约 24 小时过期;
  扫码确认现在会先自动续期(refresh token 换新,不行则用存储密码无头重登,
  与“待确认登录”检查一致),都失败时明确提示“会话已过期,请重新登录”。
- **批准被拒时误显示成功。** Steam 返回不带 `x-eresult` 头的非 2xx 响应
  (如过期 token 的裸 401)曾被当作成功,界面显示“已批准”而电脑端一直等待;
  现在会正确报错。

## [v0.78.2] — 2026-07-05

### Added
- **Windows portable build**: a dedicated workflow packs the app into a
  **single-file** `AVA-…-portable.exe` (Enigma Virtual Box) — nothing to
  install, runs from anywhere; account data stays in the per-user data
  directory just like the folder build.
- **Scene-style Windows installer**: a single-file `AVA-…-setup.exe` built
  from a dedicated Flutter installer app — frameless neon/pixel UI with
  scanlines and a greetz marquee; per-user install (no UAC), Start-menu /
  desktop shortcuts, proper Add/Remove entry, and an uninstaller that never
  touches account data.
- **Desktop release CI**: `v*` tags (or manual dispatch) now build the Windows
  installer and a Linux x86_64 AppImage; tag builds attach both to the GitHub
  Release. Artifacts are no longer double-zipped.

—

### 新增
- **Windows 便携版**:独立 workflow 打包出**单文件** `AVA-…-portable.exe`
  (Enigma Virtual Box),免安装、放哪都能跑;账户数据与普通版一样写入
  用户数据目录。
- **scene 风格 Windows 安装包**:单文件 `AVA-…-setup.exe`,由专门的 Flutter
  安装器应用构建——无边框霓虹像素界面、扫描线与跑马灯动效;装到用户目录免 UAC,
  自带开始菜单/桌面快捷方式与标准卸载项,卸载不会动账户数据。
- **桌面版发布 CI**:打 `v*` tag(或手动触发)会构建 Windows 安装包与
  Linux x86_64 AppImage;tag 构建会自动附到 GitHub Release,产物不再出现双层 zip。

## [v0.78.1] — 2026-07-04

### Changed
- Saving the Steam password at login is now **opt-in** (previously checked by
  default). Exported maFiles no longer include a saved password unless
  explicitly ticked in the export dialog — a plaintext maFile already grants
  authenticator takeover; it shouldn't hand over the account password too.
- Building a release AAB now **fails outright** when the upload key
  (`android/key.properties`) is missing, instead of silently producing a
  debug-signed bundle. `flutter run --release` is unaffected.

### Removed
- Unused dependencies `cookie_jar`, `dio_cookie_manager`, `asn1lib`.

—

### 变更
- 登录时保存 Steam 密码改为**显式勾选**（此前默认勾选）。导出的 maFile 默认不再携带
  已保存的密码，除非在导出对话框中显式勾选——明文 maFile 本身已足以接管验证器，
  不应再连账户密码一起交出去。
- 缺少上传密钥（`android/key.properties`）时，构建 release AAB 会**直接失败**，
  而不是悄悄产出 debug 签名的包；`flutter run --release` 不受影响。

### 移除
- 未使用的依赖 `cookie_jar`、`dio_cookie_manager`、`asn1lib`。

## [v0.78.0] — 2026-07-04

Rolls up v0.77.1–v0.77.3 for release: animated avatar-frame flicker fix,
Steam++ / Watt Toolkit maFile import (incl. no-SteamID code-only accounts),
and the sign-in-instead-of-retry flow on expired sessions. READMEs updated.

## [v0.77.3] — 2026-07-04

### Changed
- When a Steam session has expired and can't be refreshed silently, the market
  and confirmations screens now offer a **Sign in** button instead of a
  pointless Retry — one tap re-establishes the session (and, for a code-only
  imported account, fills in the real SteamID).

—

### 变更
- 当 Steam 会话已过期且无法静默刷新时,市场页和确认页现在提供**「登录」**按钮,而不是
  无用的「重试」——一键即可重建会话(对仅验证码导入的账户还会补齐真实 SteamID)。

## [v0.77.2] — 2026-07-04

### Fixed
- Importing a maFile exported by other tools (Steam++ / Watt Toolkit) no longer
  fails. AVA now recognizes their SteamID variants (decimal or base64 aliases,
  or the SteamID in the filename) and normalizes the shared secret. A maFile
  with no SteamID at all is imported as a code-only account — its Steam Guard
  codes work immediately, and signing in later (to use the market or trade
  confirmations) fills in the real SteamID automatically.

—

### 修复
- 其他工具(Steam++ / Watt Toolkit)导出的 maFile 现在能正常导入。AVA 会识别它们的
  SteamID 变体(十进制或 base64 别名、或文件名里的 SteamID)并规范化共享密钥。完全
  没有 SteamID 的 maFile 会作为「仅验证码」账户导入——验证码立即可用,之后登录(使用
  市场或交易确认时)会自动补齐真实 SteamID。

## [v0.77.1] — 2026-07-04

### Fixed
- Animated avatar frames that use offset sub-regions (many Steam avatar frames)
  flickered badly — the image library returns those APNG frames with the wrong
  buffer size and no offset/blend/dispose info. AVA now parses and composites
  the APNG itself (honoring the palette + per-frame region, blend and dispose),
  so animated frames play smoothly with their transparent centre intact.

—

### 修复
- 使用偏移子区域的动态头像框(许多 Steam 头像框如此)会严重闪烁——图像库返回的
  这类 APNG 帧缓冲区大小错误且缺少偏移/混合/dispose 信息。AVA 现在自行解析并合成
  APNG(正确处理调色板 + 每帧区域、混合与 dispose),动态头像框播放流畅,透明中心
  也保留。

## [v0.77.0] — 2026-07-03

### Fixed
- Third adversarial-audit pass (10 findings, all with tests):
  - **Adding an authenticator now aborts if it can't be saved locally**
    (disk full / read-only), showing the revocation code so you can remove the
    pending authenticator — previously the secret could be lost while Steam
    Guard attached to the account.
  - **Desktop data moved to the per-user app directory** (was next to the
    executable, which upgrades/reinstalls could wipe); existing data migrates
    on first run.
  - **Exported maFiles are deleted from the temp folder after sharing** (they
    contain a session token; a copy used to linger).
  - Concurrency-safe local writes (no more clobbered temp files / lost updates).
  - Cancelling a market listing now reports real success/failure; an expired
    session in the market shows a sign-in prompt instead of an empty inventory.
  - Approving a sign-in requires a live session token, and the full approve
    screen now shows the sign-in's origin (location/IP/device) before you
    approve, matching the quick-scan flow.
  - Avatar images are only downloaded from Steam's CDN and capped at 2 MiB
    (a tampered maFile can't make the app fetch arbitrary URLs).
  - The feedback endpoint is rate-limited per IP.

—

### 修复
- 第三轮对抗审计(10 项,均带测试):
  - **添加验证器时若无法在本机保存(磁盘满 / 只读)会中止**,并显示撤销码以便你
    移除待处理的验证器——此前 secret 可能丢失而 Steam Guard 已绑定到账户。
  - **桌面数据迁到每用户应用目录**(原来放在可执行文件旁,升级/重装可能抹掉);
    存量数据首次运行时自动迁移。
  - **导出的 maFile 分享后从临时目录删除**(其中含会话 token,以前会残留一份)。
  - 本机写入并发安全(不再互踩临时文件 / 丢更新)。
  - 取消市场挂单如实反映成功/失败;市场里会话过期显示重新登录提示而非空库存。
  - 批准登录要求有效会话 token,完整批准页在批准前也展示登录来源(位置/IP/设备),
    与快捷扫码一致。
  - 头像只从 Steam CDN 下载且限制 2 MiB(被篡改的 maFile 无法让 App 下载任意 URL)。
  - 反馈端点按 IP 限流。

## [v0.76.0] — 2026-07-03

### Changed
- "Auto-confirm market transactions" now shows what it actually does (as an
  inline description, no longer under a redundant "Confirmations" header): it
  only pre-ticks the confirm box when you list an item, so a new listing is
  confirmed right after creation. It never confirms anything in the background.

### Removed
- The "Periodically check for confirmations", "Check all accounts" and
  "Auto-confirm trades" settings. They were carried over from the legacy SDA
  manifest for file compatibility but were never wired to any behaviour in AVA
  — toggling them did nothing, which is especially misleading for switches that
  imply automatic trade approval. Only "Auto-confirm market transactions"
  remains (it sets the default of the sell sheet's confirm checkbox). The
  underlying manifest fields are kept for .NET maFile round-trip compatibility.

—

### 变更
- 「自动确认市场交易」现在标明了它的真实作用(以内联说明呈现,不再套一层多余的
  「确认」分组标题):它只是在上架物品时预先勾选确认框,让新上架在创建后立即被
  确认,不会在后台确认任何东西。

### 移除
- 「周期检查确认」「检查所有账户」「自动确认交易」三个设置。它们是为兼容旧版 SDA 的
  manifest 文件格式而保留的字段,在 AVA 里从未接任何行为——拨动毫无效果,尤其"自动
  确认交易"这种暗示自动同意交易的开关极具误导。仅保留「自动确认市场交易」(它决定
  出售面板确认勾选框的默认状态)。底层 manifest 字段保留以兼容 .NET maFile 往返。

## [v0.75.2] — 2026-07-03

### Fixed
- Changing the unlock PIN now asks you to confirm the new PIN a second time.
  Previously a single mistyped new PIN would re-encrypt the vault under a value
  you couldn't reproduce — a lockout. (First-run PIN setup already confirmed.)

—

### 修复
- 修改解锁 PIN 时现在需要再次确认新 PIN。此前若新 PIN 输错一次,保险库会被用一个你
  无法复现的值重新加密——直接锁死。(首次设置 PIN 本就有确认。)

## [v0.75.1] — 2026-07-03

### Security
- Second hardening pass (no user-visible change; all with regression tests):
  updating or re-keying an encrypted account is now crash-safe (writes a fresh
  file and commits the manifest atomically, so a crash can't leave the
  manifest describing a different file's ciphertext); a single corrupt maFile
  no longer blanks the whole account list; the "reset encrypted data" escape
  hatch commits a clean store before dropping keys so it can never half-brick;
  login QR codes are only accepted from Steam hosts; the community request
  gates its initial URL on a Steam origin; and market auto-confirm approves
  only the listing you just made, never a confirmation already pending.

—

### 安全
- 第二轮加固(无可见变化,均带回归测试):更新或换密加密账户改为崩溃安全(先写新
  文件再原子提交 manifest,崩溃不会让 manifest 与密文错配);单个损坏的 maFile 不再
  清空整个账户列表;「重置加密数据」逃生入口先提交干净库再清密钥,不会半砖;登录
  二维码只接受 Steam 域;社区请求的初始 URL 也做 Steam origin 门控;市场自动确认只
  批准本次上架,不再误批已有待确认项。

## [v0.75.0] — 2026-07-03

### Security
- Hardening pass from an adversarial audit (no user-visible change; all with
  regression tests): session cookies are no longer carried across a redirect
  to a non-Steam origin; adding an authenticator now waits for a fresh code
  window between retries instead of hammering the same code; tampered-manifest
  filenames can no longer escape the maFiles folder; account writes are now
  crash-atomic (temp-file + rename, payload before manifest); the debug log
  attached to feedback is scrubbed of any token/secret-shaped text; the
  feedback endpoint sanitizes fields and no longer echoes internal errors.

—

### 安全
- 一轮对抗性审计的加固(无可见变化,均带回归测试):会话 cookie 不再在跳转到非
  Steam 域时被携带;添加验证器时重试会等待新的验证码窗口,不再反复提交同一个码;
  被篡改的 manifest 文件名无法再逃出 maFiles 目录;账户写入改为崩溃安全(临时文件
  + 重命名、先写 payload 再写 manifest);随反馈附带的调试日志会清除任何疑似
  令牌/密钥的文本;反馈端点会清洗字段且不再回显内部错误。

## [v0.74.3] — 2026-07-03

### Added
- A "Can't unlock?" escape hatch on the unlock screen: if the vault has become
  undecryptable (restored backup, migrated phone), you can now wipe the
  encrypted data and start fresh from inside the app — with a clear warning —
  instead of digging through system settings to clear app data.

—

### 新增
- 解锁页新增「无法解锁？」逃生入口:当保险库已无法解密(备份恢复、换机迁移)时,
  可在应用内(带明确警告)清除加密数据重新开始,不用再去系统设置里清数据。

## [v0.74.2] — 2026-07-03

### Fixed
- Android backups and phone-migration tools no longer carry AVA's data: the
  vault key lives in the hardware Keystore and never leaves the device, so a
  restored copy could never be decrypted — it just produced a vault that
  rejected the correct PIN forever, fixable only by clearing app data. A
  restored install now starts clean; re-import your maFiles instead.

—

### 修复
- AVA 的数据不再随 Android 备份 / 换机迁移工具走:保险库密钥存于硬件 Keystore、
  永不离开设备,恢复出来的数据永远无法解密——只会得到一个"正确 PIN 也一直被拒"
  的保险库,只能清数据自救。现在恢复安装会以干净状态启动,重新导入 maFile 即可。

## [v0.74.1] — 2026-07-03

### Fixed
- The QR scanner crashed with a native null-pointer error in release builds:
  R8 full-mode shrinking stripped ML Kit's reflectively-discovered barcode
  components. Added keep rules; the camera now opens.
- The scan button no longer collides with the skins' corner-bracket
  decoration, and its label now reads "Sign in with QR code" (the
  approve/reject wording only appears on the confirm step).

—

### 修复
- 扫码页在 release 包中闪退(原生空指针):R8 full mode 把 ML Kit 反射注册的
  条码组件剥掉了。已加 keep 规则,相机可以正常打开。
- 扫码按钮不再与皮肤的角落装饰框重叠;入口文案改为「扫码登录」(批准/拒绝的
  措辞只出现在确认步骤)。

## [v0.74] — 2026-07-03

### Added
- **QR sign-in approval moved front and center**: a scan button now sits in the
  home screen's top-right corner. Tap it to scan a Steam login QR code and the
  approval runs as the currently selected account, with a confirmation dialog
  showing where the sign-in comes from (location / IP / device) before you
  approve or reject. Desktop opens the paste-the-link flow preselected to the
  current account. (Previously buried in the "add account" menu.)

—

### 新增
- **扫码批准登录挪到台前**:主界面右上角新增扫码按钮,点击即以当前选中账户扫描
  Steam 登录二维码,批准前会弹出确认框展示登录来源(位置 / IP / 设备)再选择
  批准或拒绝。桌面端打开粘贴链接的流程并预选当前账户。(此前藏在「添加账户」
  菜单里。)

## [v0.70.5] — 2026-07-03

### Fixed
- Pull-to-refresh on the home screen needed a near full-screen drag on small
  phones: the trigger was measured in post-rubber-band scroll pixels, and the
  bounce damping scales with viewport height. It now measures real finger
  travel (~130dp), consistent on every screen size. (beta feedback)

—

### 修复
- 小屏手机上主界面下拉刷新几乎要划满全屏才触发:原判定用的是橡皮筋阻尼后的滚动
  像素,而阻尼强度与视口高度挂钩。现改为按手指真实位移(约 130dp)判定,任何屏幕
  尺寸手感一致。(内测反馈)

## [v0.70.4] — 2026-07-03

### Fixed
- A wrong password during sign-in dumped a raw `SteamApiException(…)` at the
  user. Common sign-in errors (wrong password, rate limiting, wrong guard
  code) now show plain localized messages. (beta feedback)

—

### 修复
- 登录密码输错时,界面直接抛出原始的 `SteamApiException(…)` 异常文本。常见登录
  错误(密码错误、请求过频、验证码不符)现在显示友好的本地化提示。(内测反馈)

## [v0.70.3] — 2026-07-03

### Added
- A show/hide toggle on the Steam password field — typing a long password
  blind was error-prone. (beta feedback)

—

### 新增
- Steam 密码输入框新增「显示/隐藏」切换——盲打长密码太容易出错。(内测反馈)

## [v0.70.2] — 2026-07-03

### Fixed
- The Steam Guard code field during sign-in only offered a number keyboard —
  Steam's email and authenticator codes contain letters. It now uses a full
  keyboard and uppercases input automatically. (beta feedback)

—

### 修复
- 登录时的 Steam 验证码输入框只提供数字键盘——而 Steam 的邮箱码和令牌码都含字母。
  现已改用全键盘并自动转为大写。(内测反馈)

## [v0.70] — 2026-07-03

### Added
- **Skin effects are now data-driven.** The ambient backdrops (matrix rain,
  pixel starfield…), HUD, scanlines and pull-to-refresh washes are rendered by
  a generic effect engine from JSON specs; the built-in Neon and Pixel skins
  ship as bundled packs (`assets/skins/*.json`) and reproduce the previous
  looks exactly. Unknown layer types degrade gracefully — groundwork for
  downloadable skin packs (schema documented in `docs/skin-schema.md`).
- **Appearance and Skins are now two separate settings.** Appearance picks
  light / dark / follow-system for the new standard look — quiet palettes
  (calm blue accent), the platform's default font, standard rounded cards,
  no ambient effects, status-bar icons following the brightness. Skins
  (None / Neon / Pixel) layer the full styled experiences on top and override
  the appearance while active. Existing theme choices migrate automatically.
- Feedback can now **attach the in-app debug log** (opt-in checkbox, off by
  default) so bug reports carry the network trace; the relay accepts the extra
  field and the privacy policy documents exactly what the log may contain.
- A one-time **backup reminder** after the first maFile import: data lives on
  this device only — keep maFiles and revocation codes backed up.

### Fixed
- Steam-served text now follows the app language: confirmation headlines and
  summaries, inventory item names and market listings are requested in the
  UI language (Chinese UI no longer shows English strings from Steam).
- Theme fonts are applied consistently: the debug log inherits the active
  theme's code font (it was hard-wired to JetBrains Mono even in Pixel), and
  the Neon matrix-rain glyphs use the bundled JetBrains Mono instead of the
  system monospace font.

### Changed
- Privacy policy reworded: the local-only guarantees are now scoped to the
  current version, and a broadened section covers planned optional online
  features (cloud sync/backup, trade notifications) — strictly opt-in, policy
  update before enablement, end-to-end encryption intent for synced secrets.
  The Chinese policy was brought in sync with the English one (it was missing
  the opt-in feedback-relay exception).

### Fixed
- The post-import backup reminder no longer implies the app can surface your
  revocation code. It now says the R-code is shown only once, when you add an
  authenticator — write it down then; it is the last resort if the device is
  lost.

### 新增
- **皮肤特效全面数据驱动。**氛围背景(矩阵雨、像素星野等)、HUD、扫描线与
  下拉刷新色染改由通用特效引擎按 JSON 规格渲染;内置霓虹/像素皮肤即两个
  标准包(`assets/skins/*.json`),视觉与此前完全一致。未知层类型优雅降级
  ——为可下载皮肤包铺路(schema 见 `docs/skin-schema.md`)。
- **「明暗」与「皮肤」拆分为两个独立设置。**明暗(跟随系统/暗色/亮色)作用于
  新增的标准外观——安静配色(蓝色点缀)、系统默认字体、标准圆角卡片、无氛围
  特效,状态栏图标随明暗自动切换;皮肤(无/霓虹/像素)在其上叠加完整风格化
  体验,启用时覆盖明暗设置。旧版已选主题自动迁移。
- 反馈功能支持**附加应用内调试日志**（可选勾选，默认关闭），错误报告可以带上
  网络跟踪现场；中转服务已支持该字段，隐私政策同步说明了日志可能包含的内容。
- 首次导入 maFile 后弹出**一次性备份提醒**：数据只存本机，请备份 maFile 与
  撤销码（R 码）。

### 修复
- 来自 Steam 的文本现在跟随应用语言:交易确认的标题/摘要、库存物品名、
  市场挂单均按界面语言请求(中文界面不再夹杂 Steam 返回的英文)。
- 主题字体全面统一:调试日志改为继承当前主题的代码字体(此前固定
  JetBrains Mono,像素主题下不匹配);霓虹主题的"矩阵雨"字符改用内置
  JetBrains Mono,不再依赖系统 monospace。

### 修复
- 导入后的备份提醒不再暗示 App 能显示撤销码。改为说明 R 码仅在添加令牌时
  显示一次——请当场抄下;设备丢失时它是最后手段。

### 变更
- 隐私政策措辞更新:"纯本地"承诺限定为当前版本,并将"云同步"一节扩展为
  「云同步与其他在线功能」(云同步/云备份、交易通知)——严格可选开启、启用前
  先更新政策、同步密钥以端到端加密为设计目标。中文版补齐了英文版已有的
  反馈中转例外说明(此前缺失)。

## [v0.65] — 2026-07-01

### Added
- **First-run gesture tutorial** (touch devices): a themed coach-mark overlay
  that spotlights the live token and physically demonstrates the account row's
  swipe panes (right → confirmations, left → refresh/export/delete), the
  long-press market entry and pull-to-refresh. Skippable, shown once.
- **Desktop support**: right-click an account row for a context menu with all
  row actions, and a sidebar refresh button on desktop platforms (mouse users
  have no pull-to-refresh). The market screen gained an app-bar refresh button.
- Batch **"Accept all" / "Reject all" now ask for confirmation** (with count and
  a warning) before acting on every pending confirmation at once.
- Retry buttons on the confirmations and market error states; the market
  inventory shows a first-load spinner and a paging indicator.
- Settings → "Gesture tutorial → Replay" to rewatch the walkthrough.
- **Manual account ordering**: a sort button next to "+" in the Accounts
  header switches the list into reorder mode — drag the handle to arrange,
  tap ✓ to finish. The order persists.
- **Settings → Feedback**: send bug reports / ideas straight to the developer
  from inside the app (message + optional contact + a version line shown in the
  form; relayed by a Cloudflare Worker to the developer's mailbox, opt-in only).

### Changed
- Themed the remaining stock-Material surfaces: dialogs, tabs and context menus
  now follow the Neon/Pixel design tokens; the "add account" sheet was redesigned
  as a floating themed panel; the welcome and empty screens got the animated
  theme ambience; destructive dialog buttons are red.
- The animated backgrounds now fade out under the status bar and the HUD frame
  stays inside the safe area — no more glyphs colliding with system icons.
- Touch targets across the app raised to 48dp (visuals unchanged).
- The unlock progress bar now fills up instead of looping endlessly.
- The application ID moved to `pro.dotslash.ava` (was `app.ava.authenticator`,
  namespace `com.sdacommunity.sda`) ahead of the first Play upload — the
  developer's own domain, consistent across Android/Linux/Windows. Existing
  side-loaded builds install in parallel: export your maFiles from the old
  copy, import in the new one, then uninstall the old.
- The swipe-right action label reads "Confirmations" (was "Trade
  confirmations" — Steam's own term, and it no longer truncates); the About
  author link now points to dotslash.pro.
- Remaining "SDA" naming was scrubbed from the project: internal theme/widget
  classes, the macOS bundle (`pro.dotslash.ava`, was `com.sdacommunity.sda`),
  the Windows project/executable metadata and the release artifact names (now
  `AVA-*`). References to the original Steam Desktop Authenticator remain only
  where they credit it or document maFile compatibility.

### Fixed
- Toggling a settings switch no longer re-locks the app (the app state is now
  updated in place instead of being rebuilt through the encrypted bootstrap).
- Settings "About" now shows the real installed version instead of a stale
  hardcoded one.
- The Settings encryption card no longer describes the retired PIN-derived
  AES-CBC scheme; it now states the real model (Keystore-held random key,
  AES-256-GCM, PIN as the unlock gate).
- The first-run tutorial spotlight now anchors to the code / account row with a
  LayerLink, so it frames the target correctly in every layout — phone, tablet
  two-pane and foldable unfolded — instead of drifting off to one side (it no
  longer relies on cross-route coordinate measurement).
- Market: "My listings" surfaces load errors (with retry), can be pull-refreshed
  when empty, and reloads after you create a listing; the sell sheet no longer
  hangs on a stuck progress bar when price data fails to load.
- The wrapped vault key, its salt and its KDF parameters are now stored as one
  atomic record instead of three separate entries — a crash in the middle of a
  PIN change can no longer tear the wrap apart and lose the vault. A corrupted
  record falls back to the previous layout and self-heals on the next unlock.
  (The old layout is removed once migrated, so downgrading to an earlier build
  afterwards is not supported.)

### Performance
- Unlock key derivation (PBKDF2, 100k iterations) moved off the UI thread — the
  unlock animation actually animates now, and the PIN/biometric screen no longer
  freezes for a moment before it.
- Swapped the PBKDF2 implementation (pointycastle → hashlib, byte-identical
  output, locked by a compatibility test) for a ~4.5× faster unlock; the KDF
  round count is now stored alongside the wrapped key so it can be tuned in
  future versions without breaking existing vaults.
- …and then dropped the round count to the RFC minimum: against a 6-digit PIN's
  10⁶ combinations no iteration count meaningfully slows an offline attacker
  (one GPU clears the whole space at 100k rounds in ~20 s) — the hardware
  Keystore is the real barrier, and the rounds only bought unlock latency.
  Unlock is now effectively instant; existing vaults migrate automatically on
  their next successful unlock.
- The animated backgrounds (digital rain, HUD, starfield, scanlines) no longer
  rebuild the widget tree every frame and pause completely while another screen
  covers them — same 60 fps visuals, much less CPU/battery.
- Network images (avatars, inventory icons) now decode at display size.
- Avatars and avatar frames are now cached on disk: every launch shows them
  instantly (and offline) instead of waiting on the network, while the existing
  background profile check still picks up avatar/frame changes and swaps the
  new image in without flashing a placeholder. Entries unused for 60 days are
  pruned automatically.

—

### 新增
- **首次启动手势教程**(触屏设备):主题化 coach-mark 引导,聚光展示实时令牌,并真实
  演示账户条目的滑动面板(右滑 → 交易确认,左滑 → 刷新/导出/删除)、长按进入市场与
  下拉刷新。可跳过,仅显示一次。
- **桌面端支持**:账户条目右键弹出包含全部操作的上下文菜单;桌面平台侧栏新增刷新
  按钮(鼠标无法下拉刷新);市场页新增标题栏刷新按钮。
- **「全部接受 / 全部拒绝」现在需要二次确认**(带数量与警告),不再一键批量生效。
- 确认页与市场错误状态新增「重试」按钮;库存首次加载显示进度、分页加载有指示。
- 设置新增「手势教程 → 重新播放」。
- **账户手动排序**:账户列表标题的 "+" 旁新增排序按钮,点击进入排序模式,拖动
  手柄调整顺序,点 ✓ 完成;顺序持久保存。
- **设置 → 反馈**:在应用内直接把 bug / 想法发给开发者(内容 + 选填联系方式 +
  表单中明示的版本信息;经 Cloudflare Worker 转发至开发者邮箱,完全由用户主动发起)。

### 变更
- 补齐了剩余原生 Material 表面的主题化:对话框、标签页、右键菜单全部遵循
  Neon/Pixel 设计令牌;「添加账户」底部菜单重做为悬浮主题面板;欢迎页与空状态页
  加入了动态主题氛围背景;破坏性对话框按钮改为红色。
- 动态背景在状态栏区域淡出、HUD 框架收进安全区——装饰元素不再与系统图标打架。
- 全应用触控目标提升到 48dp(视觉不变)。
- 解锁进度条改为填充式,不再无限循环。
- 应用包名迁移为 `pro.dotslash.ava`(原 `app.ava.authenticator`,命名空间
  `com.sdacommunity.sda`),赶在首次上传 Play 之前统一为开发者自有域名,三端一致。
  旧侧载版本会与新版并存:在旧版导出 maFiles → 新版导入 → 卸载旧版即可迁移。
- 右滑动作标签改用 Steam 官方叫法 "Confirmations"(原 "Trade confirmations",
  过长会被截断);「关于」页作者链接改为 dotslash.pro。
- 清理了项目中残留的 "SDA" 命名:内部主题/组件类名、macOS 包
  (`pro.dotslash.ava`,原 `com.sdacommunity.sda`)、Windows 工程与可执行文件
  元数据、发布产物名(现为 `AVA-*`)。仅在致谢与 maFile 格式兼容性说明处
  保留对原 Steam Desktop Authenticator 的提及。

### 修复
- 在设置页拨动开关不再导致应用重新上锁(应用状态改为原地更新,不再经过加密引导流程
  整体重建)。
- 设置页「关于」显示真实安装版本,不再是过期的硬编码版本号。
- 设置页加密卡片不再描述已废弃的「PIN 派生 AES-CBC」方案,改为如实说明现行模型
  (Keystore 持有的随机密钥、AES-256-GCM、PIN 仅作解锁门)。
- 首次教程的聚光框改用 LayerLink 锚定验证码 / 账户行,在手机、平板两栏、折叠屏展开
  等所有布局下都能正确框住目标,不再偏移(不再依赖跨路由坐标测量)。
- 市场:「我的上架」会展示加载错误(可重试)、空列表也能下拉刷新、上架成功后自动
  重载;出售面板在价格数据加载失败时不再卡死在进度条。
- 保险库密钥包裹、盐值与 KDF 参数改为单条原子记录存储(原为三条独立条目)——
  修改 PIN 途中崩溃不会再撕裂密钥记录、导致保险库永久丢失。记录损坏时自动回退旧
  布局并在下次解锁时自愈。(迁移完成后旧布局即被清除,之后不支持降级到更早版本。)

### 性能
- 解锁密钥派生(PBKDF2 十万次迭代)移出 UI 线程——解锁动画真正动起来了,输入 PIN /
  指纹后的界面也不再卡顿。
- 更换 PBKDF2 实现(pointycastle → hashlib,输出逐字节一致并有兼容性测试锁定),
  解锁约快 4.5 倍;KDF 迭代数现随包裹密钥一同存储,今后可平滑调整不破坏存量。
- ……随后把迭代数直接降到 RFC 最低值:面对 6 位 PIN 仅 10⁶ 种组合,再多的迭代也无法
  实质拖慢离线破解(一块 GPU 在 10 万轮下约 20 秒穷举全部空间)——真正的屏障是硬件
  Keystore,多余的轮数只换来解锁延迟。现在解锁几乎瞬时完成;存量保险库将在下次成功
  解锁时自动迁移。
- 动态背景(数字雨、HUD、星空、扫描线)不再每帧重建 widget 树,且在被其他页面遮挡时
  完全暂停——视觉仍是 60 fps,CPU/电量占用大幅下降。
- 网络图片(头像、库存图标)按显示尺寸解码。
- 头像与头像框现在缓存到磁盘:每次启动即时显示(离线也能显示),不再等网络;原有的
  后台资料检查仍会发现头像/头像框更新,新图就绪后无缝替换、不闪占位符。60 天未使用
  的缓存条目自动清理。

## [v0.64] — 2026-07-01

### Changed
- **Stronger at-rest encryption.** Local maFiles are now encrypted with a random
  256-bit key (AES-256-GCM) held in Android Keystore-backed storage and wrapped
  by your PIN, instead of a key derived directly from the 6-digit PIN. Copied
  maFiles can no longer be brute-forced off-device. Existing accounts migrate
  automatically and safely on your next unlock; the unlock PIN and biometric
  unlock are unchanged. Exported maFiles stay in the standard SDA format.

### Added
- A themed full-screen unlock animation (Neon / Pixel) shown while the vault is
  decrypted, instead of a frozen screen.
- A confirmation warning before exporting an (unencrypted) maFile, with an extra
  note when the account has a saved Steam password.
- Android release signing wired from `key.properties` (Play App Signing ready).

—

### 变更
- **更强的本地加密。** 本机 maFile 现在用一个随机 256 位密钥(AES-256-GCM)加密,
  该密钥存放在 Android Keystore 支持的安全存储中、由你的 PIN 包裹,不再由 6 位 PIN
  直接派生。拷走的 maFile 离开本机无法再被暴力破解。存量账户会在下次解锁时自动、
  安全地迁移;解锁 PIN 与生物识别解锁体验不变。导出的 maFile 仍为标准 SDA 格式。

### 新增
- 解锁时显示符合主题的全屏动画(Neon / Pixel),不再干等卡屏。
- 导出(未加密)maFile 前弹出确认警告;账户存有 Steam 密码时额外提示。
- Android 正式签名改为从 `key.properties` 读取(已就绪 Play App Signing)。

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
