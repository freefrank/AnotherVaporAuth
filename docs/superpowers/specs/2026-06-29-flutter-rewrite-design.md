# Steam Desktop Authenticator — Flutter 跨平台重写设计

> 状态：草案（待用户复核）
> 日期：2026-06-29
> 作者：SDA 社区 / Claude

## 1. 背景与目标

现版本是 **.NET 8 WinForms** 桌面程序（仅 Windows，约 4700 行 C#），依赖 `SteamAuth` 子模块与 `SteamKit2 3.0`。核心能力：

- Steam Guard TOTP 验证码生成
- 交易 / 市场确认（现用内嵌 WebView 拉取 mobileconf 页面）
- 账户管理 + 加密 maFiles（PBKDF2 + AES-256-CBC）
- 登录、添加验证器（手机 SMS）、会话刷新、导入账户、设置

**重写目标**：用 **Flutter (Dart)** 做现代化、轻量、极快的跨全平台实现 ——
**Windows / macOS / Linux 桌面 + Android**，单一代码库。**总体逻辑不变，功能 100% 对齐现版本**。

### 硬约束

1. **数据完全兼容**：新版能直接读取 / 写入现有 `maFiles`（含加密格式），老用户零成本迁移。
2. **功能全量对齐**：包含联网功能（登录、确认、添加验证器、会话刷新）。
3. **逻辑不变**：算法与协议与现版本等价（TOTP、确认签名、加密方案、Steam 新登录协议）。

## 2. 现成方案复用评估

| 能力 | 现成方案 | 结论 |
|---|---|---|
| TOTP 验证码生成 | `steam_auth`(Dart) / `node-steam-totp` 算法 | 移植/参考（纯算法稳定） |
| 确认哈希（identity_secret 签名 mobileconf） | 同上 | 移植（协议稳定） |
| maFile 加密格式 | 无（项目私有 PBKDF2+AES-CBC） | Dart 精确复刻 |
| Steam 新登录协议（RSA→BeginAuthSession→Poll→JWT） | `steam_auth`(Dart, 1.0.7, 4 年未更新)**已失效**（用废弃旧 CAPTCHA 流程）；无维护中的 Dart 包 | **自建**，参考 [node-steam-session](https://github.com/DoctorMcKay/node-steam-session) |

**关键洞察**：

- `steam_auth`(Dart) 不能整包采用，其登录基于 Steam 已废弃协议；但 TOTP / 确认算法可作移植起点。
- Steam 新登录协议本质是几个 `api.steampowered.com` 的 `IAuthenticationService` web 调用（node-steam-session 已用纯 HTTPS 实现，无需 SteamKit 等价物），完全可移植到 Dart。

## 3. 架构

三层，核心层与平台 / UI 解耦。

```
┌─────────────────────────────────────────────┐
│  UI 层 (Flutter, Material 3)  — 各屏幕         │  桌面 + Android 共用
│  状态管理: Riverpod                            │
├─────────────────────────────────────────────┤
│  服务层 (services/)  纯 Dart，可单测            │
│  • AccountStore   账户/manifest 管理            │
│  • SessionManager 会话生命周期 + 刷新           │
│  • ConfirmationService 轮询 + 自动确认          │
│  • StorageProvider 路径/存储抽象（按平台实现）  │
├─────────────────────────────────────────────┤
│  核心库 (steam_core/, 纯 Dart, 零 Flutter 依赖) │
│  • SteamTotp            生成验证码（移植）       │
│  • Confirmations        identity_secret 签名+API│
│  • SteamAuthSession     新登录协议（自建）       │
│  • AuthenticatorLinker  添加验证器+手机+SMS      │
│  • MaFile               PBKDF2+AES-256-CBC 编解码│
│  • Manifest / ManifestEntry  manifest.json 读写  │
│  • SteamGuardAccount    账户模型                 │
└─────────────────────────────────────────────┘
```

**设计原则**：核心库零 Flutter / 平台依赖，可在纯 Dart 下单测；服务层封装有状态流程；UI 仅消费服务层。

## 4. 模块映射（逻辑不变）

| 现版本 (C#) | 新版本 (Dart) | 说明 |
|---|---|---|
| `FileEncryptor.cs` | `steam_core/ma_file.dart` | 精确复刻 PBKDF2(50k,SHA1)+AES-256-CBC+PKCS7+base64 |
| `Manifest.cs` | `steam_core/manifest.dart` + `services/account_store.dart` | 同 manifest.json schema，完全兼容 |
| `SteamAuth/SteamGuardAccount` | `steam_core/steam_guard_account.dart` | shared/identity_secret、Session(JWT) |
| `LoginForm` + SteamKit2 | `steam_core/steam_auth_session.dart` | 新协议自建（RSA + BeginAuthSession + Poll） |
| `AuthenticatorLinker` | `steam_core/authenticator_linker.dart` | 添加验证器 + 手机 + SMS finalize |
| `ConfirmationFormWeb` (WebView) | `steam_core/confirmations.dart` + 原生列表 UI | **改进**：用 mobileconf JSON API 原生渲染，弃用内嵌 WebView（更轻更快，逻辑等价） |
| 各 WinForms 窗体 | Flutter 屏幕（见 §5） | |
| `Program.cs`/命令行 `-k` | `main.dart` + 启动参数 | 解锁口令传入等价 |

### 4.1 maFile 兼容性细节（核心）

- `manifest.json`：字段 `encrypted` / `first_run` / `entries[]`（`encryption_iv` / `encryption_salt` / `filename` / `steamid`）/ `periodic_checking*` / `auto_confirm_*` —— **逐字段对齐**。
- 每个 `<steamid>.maFile`：`SteamGuardAccount` 的 JSON；加密时为 base64 密文。
- 加密：`PBKDF2(password, base64-decode(salt), 50000 轮, HMAC-SHA1)` → 32 字节 key；`AES-256-CBC`，IV = base64-decode(iv)，PKCS7 padding；输出 base64。
- 实现库：`pointycastle`（纯 Dart，跨平台一致）。
- **回归测试**：用真实旧版 maFile 做加解密往返，断言与 C# 输出一致。

## 5. 屏幕映射

| 屏幕 | 对应现窗体 | 要点 |
|---|---|---|
| 主屏：账户列表 + 当前验证码 + 倒计时进度环 + 复制 | `MainForm` | 默认离线可用 |
| 欢迎 / 首次设置 | `WelcomeForm` | 引导导入或登录 |
| 解锁（输入加密口令） | `InputForm` 口令流程 | 启动时若加密则要求 |
| 登录（用户名/密码 + 设备确认/邮箱码；可选扫码登录） | `LoginForm` | 新协议 |
| 添加验证器向导（手机号→SMS→撤销码确认） | `PhoneInputForm` + 流程 | 必须已登录 |
| 确认列表（交易/市场，批量接受/拒绝） | `ConfirmationFormWeb` / `TradePopupForm` | 原生渲染 |
| 导入账户（选择 .maFile） | `ImportAccountForm` | 离线 |
| 设置（加密口令、周期检查、自动确认、排序） | `SettingsForm` | |

## 6. Steam 协议层（联网）

### 6.1 登录会话 `SteamAuthSession`

参照 node-steam-session 的纯 HTTPS 流程：

1. `GetPasswordRSAPublicKey` → 取 RSA 公钥（mod/exp），RSA 加密密码。
2. `BeginAuthSessionViaCredentials`（平台类型 MobileApp）→ 返回 `client_id` / `steamid` / 允许的确认方式。
3. 按需 `UpdateAuthSessionWithSteamGuardCode`（邮箱码 / 设备码）或等待移动端 / 二维码确认。
4. 轮询 `PollAuthSessionStatus` → 得到 `access_token` / `refresh_token`（JWT）。
5. 组装 `SessionData { steamId, accessToken, refreshToken }` 存入 maFile。

可选：`BeginAuthSessionViaQR` 作为扫码登录入口（后续增强）。

### 6.2 会话刷新

`access_token` 过期时用 `refresh_token` 换新（对应现版本 LoginType.Refresh）。

### 6.3 确认 `Confirmations`

- `GET /mobileconf/getlist` 带 `p`(deviceid) / `a`(steamid) / `k`(用 identity_secret 生成的 HMAC-SHA1 签名) / `t`(时间) / `tag=list` / `access_token`。
- 返回 JSON 确认列表 → 原生渲染。
- 接受 / 拒绝：`GET /mobileconf/ajaxop`（tag=accept/reject，单个）或 multi 端点（批量），同样带签名。
- 签名算法与现版本 `SteamGuardAccount.GenerateConfirmationHashForTime` 等价。

### 6.4 添加验证器 `AuthenticatorLinker`

对应现 `AuthenticatorLinker`：`AddAuthenticator`（截获 shared/identity_secret、revocation_code）→ 若需手机则 `MustProvidePhoneNumber` → `FinalizeAddAuthenticator(smsCode)`，状态机与现版本一致（含撤销码二次确认）。

## 7. 平台差异

- **桌面**：maFiles 存可执行目录旁的 `maFiles/`（同现版本，便于迁移）；可选系统托盘 + 后台自动确认轮询。
- **Android**：maFiles 存 app 私有目录；加密口令可选接入 Keystore / 生物识别解锁；后台确认用 WorkManager。
- `StorageProvider` 接口抽象路径与读写，两端各自实现。
- 命令行 `-k <key>` 等价支持（桌面）。

## 8. 技术选型

| 关注点 | 选型 | 理由 |
|---|---|---|
| UI 框架 | Flutter (Material 3) | 跨全平台、单代码库、原生渲染快 |
| 状态管理 | Riverpod | 轻、可测、编译期安全 |
| 加密 | pointycastle | 纯 Dart 跨平台一致 PBKDF2/AES |
| HTTP | dio + cookie jar | 拦截器 / 重试 / cookie 管理 |
| RSA | pointycastle | 密码加密 |
| 测试 | dart test（核心层）+ flutter test（UI） | 兼容性回归优先 |

## 9. 交付阶段（最终 100% 对齐）

每阶段可独立验证：

1. **核心库 + 兼容性**：MaFile / Manifest / SteamGuardAccount / SteamTotp + 用真实 maFile 的加解密 & 验证码回归单测。
2. **主屏 + 验证码**：导入 .maFile、解锁、账户列表、验证码 + 倒计时 + 复制（离线即可用）。
3. **确认**：Confirmations 协议 + 原生确认列表 + 接受/拒绝/批量。
4. **登录 / 会话刷新**：SteamAuthSession 新协议 + 刷新。
5. **添加验证器**：AuthenticatorLinker + 手机 + SMS 流程。
6. **设置 / 自动确认 / 平台增强**：周期检查、自动确认、托盘 / WorkManager、扫码登录（可选）。

## 10. 测试策略

- **兼容性回归（最高优先级）**：旧版 maFile 加解密往返、验证码与已知向量比对、确认签名与 C# 输出比对。
- 核心库纯 Dart 单测（无网络），协议层用录制响应做契约测试。
- UI widget 测试覆盖主屏与确认列表。

## 11. 非目标（YAGNI）

- 不引入云同步 / 账号体系。
- 不内嵌 WebView 渲染确认（改原生）。
- 不支持现版本未有的功能（保持逻辑等价，不做功能扩张）。
- iOS 暂不作为本次目标平台（架构不排斥，后续可加）。
