# Google Cloud SA + OAuth — 解冻清单

日期:2026-07-30 · 状态:**已完成**(随 v0.99.0 出包)·
来源:`2026-07-16-paywall-prerequisites.md` §2 展开

> 凭据全部就位、worker 八个 secret 齐、`kGoogleServerClientId` 已回填。
> **唯一没做的是 Play 沙盒联调** —— 这条链路至今一次都没被真正执行过。

**为什么是它**:订阅购买链路上唯一还断着的一环(§2 于 2026-07-18 挂起)。
Play 订阅商品可以随时建,但建完也卖不出去——worker 验不了 `purchaseToken`,
客户端也拿不到 Google 身份。

**做完之后还要发一个新版本**:`kGoogleServerClientId` 是编译期常量,回填后
必须重新出包才生效。安排时间时把这一步算进去。

---

## 产出清单(做完应得到这四样)

| # | 产出 | 去向 | 能写进本文件? |
|---|---|---|---|
| A | SA 的 `client_email` | worker secret `GOOGLE_SA_EMAIL` | ❌ 写 `.env` |
| B | SA 的 JSON 私钥 | worker secret `GOOGLE_SA_KEY` | ❌❌ **哪儿都不写** |
| C | **Web** 型 OAuth client_id | worker secret `GOOGLE_CLIENT_ID` **且** 客户端 `kGoogleServerClientId` | ✅ |
| D | **Android** 型 OAuth 客户端 **×2** | 无需回填,但少建一个就有一半用户登录失败 | ✅ |

---

## ✍️ 填空区(你填,我核)

> ⚠️ **本仓库是 public 的**(`github.com/freefrank/AnotherVaporAuth`)。
> 下面只列**本来就会公开**的值:Web/Android 的 client_id 会随 APK 一起分发、
> SHA-1 从任何一个 APK 都能提取。**A 和 B 不在这里填**,见下方专门一节。

### 公开安全的值 — 直接填在反引号里

| 项 | 值 | 核验 |
|---|---|---|
| GCP 项目 ID | `anothervaporauth` | 三份 JSON 的 `project_id` 一致 ✅ |
| **C** Web client_id | `77413736058-gc4sojuhdi4svnsajlagh7acpeqjb5mo.apps.googleusercontent.com` | JSON 顶层键是 **`web`** 且含 `client_secret` ✅ |
| **D1** Android — 上传密钥 | `77413736058-37qcr6st5gk1d2f47loat04kogleci43.apps.googleusercontent.com` | 顶层 `installed`、**无** `client_secret`/`redirect_uris` → Android ✅ |
| ↳ 它挂的 SHA-1 | `41:7C:CE:80:5D:29:A9:7A:BE:53:9D:F9:00:B9:27:C9:42:DC:02:BD` | 与 `~/ava-upload.jks` 实读一致 ✅ |
| **D2** Android — Play 应用签名 | `77413736058-refi7fkjval7lr8f5g1coa24udkispdr.apps.googleusercontent.com` | 同上 ✅ |
| ↳ 它挂的 SHA-1 | `EC:31:3F:A7:A9:C7:D0:4B:F3:45:E0:AE:3B:35:4F:D5:0B:A7:4F:FF` | Play Console → 应用完整性,格式合法且**与上传密钥不同** ✅ |

> 三个 client_id 互不相同、项目号前缀统一 `77413736058` ✅
>
> D1 / D2 的归属由用户直接指认(`refi7fkj…` 是 Play 应用签名那个),与 JSON
> 下载时间吻合(03:08 → 03:12)。**JSON 里不含指纹**,只有 GCP 控制台看得到,
> 所以「两个客户端挂的确实是两个不同的指纹」这一点我无法独立核实 —— 若不慎
> 挂成同一个,商店版登录仍会全挂,回控制台扫一眼那两行的 SHA-1 即可确认。
>
> ⚠️ **`GOOGLE_CLIENT_ID` 不是 SA JSON 里的 `client_id`。** SA JSON 那个
> (`113829588753303741058`)是服务账号自身的数字 ID。worker 用
> `GOOGLE_CLIENT_ID` 比对 **id_token 的 `aud`**(`google.ts:88`),而 `aud` 是
> **Web 客户端**的 client_id。填错的表现是登录一律失败。

### A 和 B — 不进仓库

- [x] **A**(SA 邮箱)写进仓库根 `.env`(git 忽略、权限 600),一行:
      `GOOGLE_SA_EMAIL=ava-worker@<项目>.iam.gserviceaccount.com`
- [x] **B**(JSON 私钥)**不写进任何文件**,下载后直接
      `npx wrangler secret put GOOGLE_SA_KEY`,值走管道不打印:
      `cat ~/下载的.json | python3 -c "import json,sys;print(json.load(sys.stdin)['private_key'])" | npx wrangler secret put GOOGLE_SA_KEY`
- [x] JSON 原件移到 `~/sync/`(Syncthing 同步、不进 git),与
      `ava-upload.jks`、`ava-entitlement-signing.pem` 同级对待
      **放入项目下 secrets 文件夹，请加入gitigore，请帮我执行GOOGLE_SA_KEY的设置。

### 填完告诉我,我会核这些

**能核的**:

- 三个 ID 的格式是否合法(client_id 必须以 `.apps.googleusercontent.com` 结尾)
- **C 与 D 是否是两个不同的值** —— 填成同一个是常见错误
- **D1 与 D2 是否是两个不同的 client_id、挂着两个不同的 SHA-1** —— 任何一对
  填成相同,都说明少建了一个客户端,而这正是「本地全过、商店版全挂」的成因
- 上传密钥 SHA-1 与本机 `~/ava-upload.jks` 是否对得上(我能直接读)
- 回填后 `play_channel.dart` 的 `kGoogleServerClientId` 是否**逐字符**等于 C
- `.env` 权限是否是 600、是否真被 git 忽略

**核不了的,得靠沙盒实跑**:

- C 到底是不是 **Web 型**(client_id 字符串本身看不出类型)。填错的表现是登录
  一直失败且报错含糊 —— 这是本清单第一号坑。
- SA 在 Play Console 的授权是否生效(有数小时滞后)
- 同意屏幕是否真的转成了「正式」
- worker secrets 是否设对(secret 只写不可读,我只能确认你勾了)

---

## 步骤

### 1. Google Cloud 项目

- [x] [console.cloud.google.com](https://console.cloud.google.com) 新建项目
      `ava-entitlement`(复用旧项目也行)
- [x] API 与服务 → 库 → 搜 **Google Play Android Developer API** → 启用

### 2. Service Account(产出 A、B)

- [x] IAM 与管理 → 服务账号 → 创建,名 `ava-worker`
- [x] **不用**授予任何项目角色(权限在 Play Console 那边给)
- [x] 建好后进「密钥」页 → 添加密钥 → **JSON** → 下载
- [x] JSON 里的 `client_email` → 产出 A
- [x] JSON 的 `private_key`(或整个 JSON,以 worker README 为准)→ 产出 B

> ⚠️ 这个 JSON 与 `ava-upload.jks`、`ava-entitlement-signing.pem` 同级别:
> **不进 git、不进对话**。放 `~/sync/` 下由 Syncthing 同步。

### 3. Play Console 授权 SA

- [x] Play Console → 用户和权限 → 邀请新用户 → 填**产出 A** 的 SA 邮箱
- [x] 账号权限至少勾:**查看应用信息** + **查看财务数据**
      (查订阅状态需要财务权限,少了会 403)
- ⚠️ **2026-07-30 现状:这个 SA 已被授予写权限**(为了让 `play-store-mcp`
  能发版 / 改商店文案)。**它同时是 worker 的 `GOOGLE_SA_KEY`** ——
  一把钥匙两处用,那个 Cloudflare secret 现在的爆炸半径是「往生产轨道推包」,
  而不再只是「查订阅状态」。用户知情并决定如此。
  想收窄的话:给 MCP 单独建一个 SA,两把钥匙各自最小权限。
- [x] 范围限定 AVA 一个应用即可

> 授权生效**滞后几分钟到几小时**,期间 API 回 401/403 是正常的,别急着改配置。

### 4. OAuth 同意屏幕

- [x] API 与服务 → OAuth 同意屏幕 → **External**
- [x] scope 只要默认的 `email` / `profile` / `openid`
- [x] **发布状态改成「正式(In production)」**

> 这一步不能省:留在「测试中」状态,refresh token **七天失效**,而且用户登录
> 时会看到「未验证的应用」警告。

### 5. OAuth 客户端 ×2

API 与服务 → 凭据 → 创建凭据 → OAuth 客户端 ID,**要建两个**。

#### 5a. Web 应用(产出 C)

- [x] 类型选 **Web 应用**,名 `ava-entitlement-web`
- [x] 它的 client_id 同时是 `GOOGLE_CLIENT_ID` 和 `kGoogleServerClientId`

> ⚠️ **最容易踩的坑**:Credential Manager 的 `serverClientId` **必须是 Web 型**,
> 填 Android 型的 client_id 会一直失败且报错含糊。

#### 5b. Android — **要建两个客户端**(产出 D1、D2)

GCP 的 Android 型 OAuth 客户端**只有一个 SHA-1 字段**,一个客户端登记不了两个
指纹。所以同一个包名要建**两个客户端**,各挂一个指纹:

- [x] **D1** — 类型 Android,包名 `pro.dotslash.ava`,SHA-1 填**上传密钥**的:
      `41:7C:CE:80:5D:29:A9:7A:BE:53:9D:F9:00:B9:27:C9:42:DC:02:BD`
      (本机 `~/ava-upload.jks`,2026-07-30 读取;要自己复核就跑
      `keytool -list -v -keystore ~/ava-upload.jks | grep SHA1`)
- [x] **D2** — 同样类型、**同样包名**,SHA-1 填 **Play 应用签名**的:
      Play Console → 设置 → 应用完整性 → 应用签名页抄

> ⚠️ 两个都要。只建 D1,你本地 `install -r` 装的包登录正常,**而所有从商店
> 装的用户登录必失败**——本地怎么测都测不出来,这是最难自查的一类。
> 反过来只建 D2,则是你自己的 dev 包登录不了。
>
> 这两个客户端的 client_id **代码里哪儿都不填**,建出来存在即可;
> 真正要回填的只有 Web 型那个(产出 C)。

### 6. 回填

- [x] worker:`cd infra/entitlement-worker`,三条 secret 逐个
      `npx wrangler secret put <NAME>`(值走管道,不打印明文):
      `GOOGLE_SA_EMAIL` / `GOOGLE_SA_KEY` / `GOOGLE_CLIENT_ID`
- [x] 确认 `PLAY_PACKAGE_NAME=pro.dotslash.ava` 已设
- [x] 客户端:`app/lib/src/services/play_channel.dart:17` 的
      `kGoogleServerClientId` 填**产出 C**
- [x] `npx wrangler deploy`
- [x] **重新出包并上传**(常量是编译期的,不重新构建不生效)
  ** 你来回填 **

### 7. 联调

- [x] Play Console → 设置 → **许可测试** → 加自己的 Google 邮箱
      (这些账号购买不扣真钱、退订即时生效)
- [x] 订阅商品 `ava_pro_monthly` 已创建并**激活**(见 prerequisites §1)
- [ ] 沙盒走一遍:登录 → 订阅 → worker 验 `purchaseToken` → 签发权益 → 客户端解锁

---

## 已知的坑(按会浪费你多少时间排序)

1. **`serverClientId` 必须是 Web 型** —— 填错报错含糊,极难定位。
2. **Android 客户端要建两个** —— 一个客户端只能挂一个 SHA-1。只建上传密钥
   那个,本地测试全过、商店版全挂,而且本地永远复现不出来。
3. **同意屏幕必须转「正式」** —— 否则七天后 refresh 失效,像是随机故障。
4. **SA 授权有滞后** —— 刚配完就试会 403,不是配错了。
5. **回填后必须重新出包** —— `kGoogleServerClientId` 是 `const`。

## 这一步不解决的事

### acknowledge:实情与我此前的说法不同(2026-07-30 核实)

路线图 memory 里长期写着「worker 缺 acknowledge,3 天不 ack 自动退款」——
**那是错的,当时没核实代码**。`BillingHandler.acknowledgeThen()`
(`app/android/app/src/play/kotlin/.../BillingHandler.kt:178`)在购买回调
(:167)与恢复购买(:239)两条路径上都会先 ack 再交出 `purchaseToken`,
`isAcknowledged` 时短路。**ack 是有的,在客户端。**

真正的洞在别处,而且**加一次服务端 ack 堵不住**:

```kotlin
acknowledgeThen(purchase) { ackResult ->
    if (ackResult.responseCode == OK) clearPending()?.success(purchase.purchaseToken)
    else failPending(ackResult)          // ← token 不交出去
}
```

ack 失败时 `purchaseToken` **根本不会交给 Dart**,worker 因此永远见不到它——
所以「在 `handlePlayVerify` 里补 ack」这个方案是无效的,服务端没有补救机会。

风险窗口:支付成功 → ack 失败(网络抖动、`SERVICE_DISCONNECTED`、Play 支付表
返回后 App 被低内存杀掉)→ 用户付了钱没解锁 → 3 天后 Google 自动退款。而唯一
的补救路径 `restoreViaPlay` **只有用户手动点「恢复购买」才跑**
(`paywall_screen.dart:224` 是全仓库唯一调用点),没有自动恢复。

建议的修法(开卖前做,与本清单独立):

1. **ack 失败也把 token 交给 Dart**,worker 在 `handlePlayVerify` 里调
   `purchases.subscriptions.acknowledge` 兜底(SA 已有 `androidpublisher`
   scope,ack 幂等)。把 ack 从客户端一次性动作变成服务端权威。
2. **打开付费墙时自动跑一次 restore**,去掉「用户得自己想到点恢复」这一环。
3. RTDN(Real-time Developer Notifications)最完整,但要建 Pub/Sub,量级不同。

### 其它

- 爱发电首笔真实订单联调(prerequisites §4 第 5 条)。
- `google.ts:5-9` 顶部的 `TODO(launch)` 三条待核实项(`subscriptionsv2` 响应
  结构、ack 要求、`aud` pinning)——整条 Play 链路都是照公开文档写的,
  **从未跑通过**,沙盒联调前一切都是纸面推理。
