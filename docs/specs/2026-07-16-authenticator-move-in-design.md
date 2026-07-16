# 验证器移入（Move Authenticator to This Device）— 设计文档

日期：2026-07-16 · 状态：**真机跑通**（一次性小号，折叠屏 dev 副本）·
协议层 + UI 已实现，本地 CI 绿

## 背景

登录新账户时，若该账户在别处已有手机验证器，Steam 的 `AddAuthenticator` 返回
EResult 29 / `status == 29`（DuplicateRequest），`AuthenticatorLinker.addAuthenticator()`
把它映射为 `LinkResult.authenticatorPresent`
（`app/lib/src/core/protocol/authenticator_linker.dart:67`）。

AVA 目前对这个结果的全部处理，是 `add_authenticator_screen.dart:322` 的 `_Step.present`
引导页 —— 三条**纯文案 + 外链**：

| 步骤 | 文案（`app_zh.arb:294-296`） | 实质 |
|---|---|---|
| 1 | 仍有旧手机或 Steam App？打开它 → Steam 令牌 → 移除验证器 | 让用户去别的 App 操作 |
| 2 | 有撤销代码（Rxxxxx）？打开下方页面，选择「移除验证器」 | 让用户去网页操作 |
| 3 | 两者都无法访问？通过 Steam 客服 | 让用户去客服 |

三条全是"**移出**"——教用户在 AVA 之外把旧验证器摘掉，回来点「重试」再走一遍全新绑定。
并且这里连协议实现都没有：AVA 全仓只调用了 `ITwoFactorService` 的两个方法
（`AddAuthenticator`、`FinalizeAddAuthenticator`），`RemoveAuthenticatorViaChallenge*`
一个都没有。`AppController.removeAccount()`（`providers.dart:813`）是纯本地删除，
不碰 Steam 侧。

**缺口**：没有"移入"——在 AVA 内部把验证器直接接管过来。这正是官方 Steam App
「将 Steam 令牌移至此设备」做的事。

## 为什么移入值得做

1. **不用离开 App**：现在要求用户开浏览器、登录 Steam 网页、找到 2FA 管理页、
   移除验证器，中间任何一步卡住就是流失。
2. **冷却期差别是实质性的**（2026-07-16 实测确认）：网页「移除验证器」→ 重新绑定
   会给账户挂 15 天交易/市场冷却；走移入**完全没有冷却**。现在的引导页等于在教
   用户走惩罚重得多的那条路。
3. **代码复用度高**：`Continue` 响应里的 `replacement_token` 就是一个完整的
   `AddAuthenticator` 响应体，与 `authenticator_linker.dart:126-142` 构造
   `SteamGuardAccount` 的那段字段一一对应，解析逻辑可直接抽出共用。

## 协议层

新增两个方法到 `AuthenticatorLinker`（不新建 client——它们与 Add/Finalize 共用
`session` 与 `_accessToken`）。

| 操作 | 端点 | 风险档 |
|---|---|---|
| 触发确认邮件 | `ITwoFactorService/RemoveAuthenticatorViaChallengeStart`（POST + `access_token`，请求体空） | B：非公开，但 SDA / steamguard-cli 长期在用 |
| 换发新令牌 | `ITwoFactorService/RemoveAuthenticatorViaChallengeContinue`（POST + `access_token`） | B：同上 |

### 字段布局（已对照 SteamDatabase/Protobufs 核实 + 真机验证）

权威来源：`steam/steammessages_twofactor.steamclient.proto`。2026-07-16 真机跑通，
`ChallengeContinue: success=true replacement=217B`。

⚠️ **`success` 是 optional bool，Steam 填不填全看心情——不能当成功信号。**
实测 `Start` 成功时返回 **eresult=OK + 0 字节空 body**（`success` 根本不存在），
而 `Continue` 成功时又确实填了 `success=true`。因此：
- `Start`：以 eresult 为准（`callProtobuf` 已在非 OK 时抛异常），
  `fields[1]?.asBool ?? true` —— 只有显式 false 才算失败。
- `Continue`：以 **`replacement_token` 是否存在**为准。若把缺失的 `success`
  读成 false，会把一次已完成的换发报成"验证码错误"，而旧验证器此时已死，
  用户重试必然失败 → 账户永久锁死。两处都有回归测试锁住。

注意 `replacement_token` 的类型是 `CRemoveAuthenticatorViaChallengeContinue_Replacement_Token`，
**不是** `CTwoFactor_AddAuthenticator_Response`；但字段 1–10 逐字段一致（仅 11/12 不同，
且本流程不读），所以复用 `_accountFromAddResponse` 成立。

```
CTwoFactor_RemoveAuthenticatorViaChallengeStart_Response
  1: success (bool)

CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Request
  1: sms_code (string)          // 实为邮件里的代码，字段名是历史遗留
  2: generate_new_token (bool)  // 必须 true —— false 就成了真·移出
  3: version (uint32) = 2

CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response
  1: success (bool)
  2: replacement_token (CTwoFactor_AddAuthenticator_Response)
       // 内层布局与 addAuthenticator() 已解析的完全一致：
       // 1 shared_secret, 2 serial_number, 3 revocation_code, 4 uri,
       // 5 server_time, 6 account_name, 7 token_gid, 8 identity_secret,
       // 9 secret_1, 10 status
```

### 新的 LinkResult 分支

```dart
enum LinkResult {
  ...
  challengeEmailSent,   // Start 成功，等用户输邮件码
  movedIn,              // Continue 成功，新 secret 已到手且已激活
  badChallengeCode,     // Continue 拒绝了邮件码
}
```

### 重构：抽出 `_accountFromAddResponse(Map<int, ProtoField>)`

`addAuthenticator()` 第 126-142 行那段构造 `SteamGuardAccount` 的代码抽成私有方法，
`Continue` 解析 `replacement_token` 时复用。**注意两处差异**：

- `fullyEnrolled`：Add 路径是 `false`（等 finalize）；移入路径的 `replacement_token`
  **是已激活的，不需要 `FinalizeAddAuthenticator`**，应为 `true`。此点需真机确认。
- `deviceId`：移入要生成本机新的 `SteamTotp.generateDeviceId(steamId)`，
  不能沿用 `linkedAccount?.deviceId`。

## UI 层

`_Step.present` 页面改版，不是替换：

- **顶部新增主按钮**「把验证器移到本设备」→ 调 Start → 进入新的 `_Step.challengeCode`。
- **新增 `_Step.challengeCode`**：一个输入框收邮件码 + 确认按钮 → 调 Continue。
  文案要说清「旧设备/旧 App 上的验证器会立即失效」。
- **现有三步引导降级**为可折叠的 fallback 区（默认收起，标题类似「无法收邮件？」）。
  邮箱丢失的用户仍然只能走网页/客服，这条路**必须保留**。

`_stepIndex` / `showStepper` 的判断（`add_authenticator_screen.dart:168-186`）要把
`challengeCode` 一并排除在步进条之外。

## 风险与硬性约束

### 1. 持久化时序 —— 本设计最危险的一点

`Continue` 返回的那一刻，Steam 侧**旧验证器已作废、新 secret 已生效，且不可撤销**。
这比 `AddAuthenticator` 危险：Add 有 finalize 作第二道关卡，用户能在 finalize 前用旧
R 码撤销；移入是**一步原子完成**的，没有回退点。

因此：
- Continue 返回后**立刻同步** `persistAccount`，沿用
  `add_authenticator_screen.dart:84-88` 那条铁律；
- 存盘失败时不能只报错——必须把**新 R 码 + shared_secret 全文**摊在屏幕上
  （可复制），提示用户立即抄写/截图。否则账户直接锁死：旧的没了，新的没存。

### 2. R 码换新

`Continue` 返回的是**新的** revocation code，旧 R 码当场作废。用户若留着旧 R 码
会以为自己有后路，其实没有。UI 必须明说这一点。

### 3. 测试受限

这条链路每一步都是对真实账户的、不可逆的写操作：
- 折叠屏（192.168.1.83）上是真实 Steam 数据，按 CLAUDE.md 硬性约束不能做这类操作；
- 模拟器 mock 账户覆盖不到（没有真实 Steam 侧状态）。

**唯一可行路径**：协议层用 fixture 做单测（覆盖字段解析、`generate_new_token=true`
的写入、错误码映射），真实链路只能拿**一次性小号**验证一次。在拿到小号前，这个
feature 不应合并到发布分支。

### 4. 邮箱依赖

`Start` 依赖账户邮箱可访问。邮箱也丢了的用户只剩客服一条路——这是保留现有三步
引导作 fallback 的原因。

## 实施顺序

1. ✅ `AuthenticatorLinker`：抽出 `_accountFromAddResponse`，现有 Add 路径改用它，
   `flutter test` 无回归。
2. ✅ 加 `moveInStart()` / `moveInContinue(String code)` + 新 `LinkResult` 分支。
3. ✅ fixture 单测（`app/test/core/authenticator_move_in_test.dart`，9 例）。
4. ✅ UI：`_Step.challengeCode` + `_Step.present` 改版 + l10n 中英文案。
5. ✅ 一次性小号真机验证（2026-07-16，折叠屏 dev 副本）。

## 验证结果（2026-07-16）

小号需**已在别处绑定验证器**才会撞到 EResult 29、进入 `_Step.present`。
实测环境：折叠屏并存的 `pro.dotslash.ava.dev`（见下节）。

- [x] `RemoveAuthenticatorViaChallengeStart` 真的触发了确认邮件。
      **但首次实测失败**：Steam 返回 eresult=OK + **0 字节空 body**，
      `success` 字段压根不存在，`?? false` 把成功判成了失败——邮件已发出，
      用户却看到"添加验证器失败"且进不了输入页。已修 + 回归测试。
- [x] `replacement_token` 在字段 2、内层 `shared_secret` 在字段 1：
      实测 `replacement=217B`，解析成功。
- [x] 存盘成功（未触发摊 secret 的失败页）。
- [x] **`fullyEnrolled: true` 成立**：移入后首页直接出码，确认不需要
      `FinalizeAddAuthenticator`。`replacement_token` 是已激活的。
- [x] R 码确实换新，旧 R 码作废。
- [x] **冷却期：没有挂 15 天交易冷却** —— 这是本功能的全部理由，实测成立。
      对比：网页「移除验证器」→ 重新绑定，必挂 15 天。
- [ ] 存盘失败分支演练（可临时让 `persistAccount` 返回 false）：失败页必须摊出
      可复制的新 R 码 + secret，且**不提供** Close 按钮。
      —— 唯一未演练项；该分支只有代码审查保证，没跑过。

## 真机调试环境（踩坑记录）

折叠屏上的 AVA 是 **Play 版**（`installerPackageName=com.android.vending`），走
Play App Signing——商店用 Google 持有的 key 重签名，本地只有 upload key，
**签名永远不匹配**，`install -r` 必然 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`。
唯一能签名匹配的路是卸载重装 = 清空真实 maFiles，**禁止**。

解法：debug buildType 加 `applicationIdSuffix = ".dev"` + debug manifest 覆盖
`android:label="AVA dev"`，装成并存的独立应用（空数据，正好用小号验证）。
release 的 applicationId 一个字没动，发布流程不受影响。两个图标必须能一眼分清——
选错图标就是不可逆操作落到真实账户上。
