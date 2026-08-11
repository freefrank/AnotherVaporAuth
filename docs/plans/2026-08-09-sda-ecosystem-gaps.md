# SDA 生态扫描：值得补的功能（挂起，下个版本）

2026-08-09。对 GitHub 上 SDA 系 / maFile 兼容项目做了一轮扫描，逐条对照 AVA 现状。
**本文只记录结论与证据，没有动任何代码。**

对照过的项目（star 数与最后更新取自扫描当天）：

| 项目 | ★ | 语言 | 最后更新 | 相关性 |
|---|---|---|---|---|
| [Jessecar96/SteamDesktopAuthenticator](https://github.com/Jessecar96/SteamDesktopAuthenticator) | 3809 | C# | 2026-08 | 原版 SDA，**已宣布停止维护** |
| [dyc3/steamguard-cli](https://github.com/dyc3/steamguard-cli) | 1019 | Rust | 2026-08 | 活跃，CLI |
| [YifePlayte/SteamGuardDump](https://github.com/YifePlayte/SteamGuardDump) | 333 | Kotlin | 2026-08 | Xposed，从官方 App 抠密钥 |
| [geel9/SteamAuth](https://github.com/geel9/SteamAuth) | 318 | C# | 2026-07 | SDA 底层库 |
| [achiez/NebulaAuth](https://github.com/achiez/NebulaAuth-Steam-Desktop-Authenticator-by-Achies) | 119 | C# | 2026-08 | **功能最全的现代重写** |
| [Kvisk/steam-authenticator-android](https://github.com/Kvisk/steam-authenticator-android) | 5 | Kotlin | 2026-06 | Android 直接同类，MIT |
| [ManeWreck/SDA-plus-plus-mobile](https://github.com/ManeWreck/SDA-plus-plus-mobile) | 2 | Kotlin | 2026-08 | Android，WebDAV 同步 |

> **原版 SDA 已停更**，README 原话：「no longer supported and will not receive any
> more updates」。这是 AVA 现在占的位置，推广文案可以直接引用。

---

## P0 · 导入 SDA 的**加密** maFile（**只缺导入流程，密码学早就有了**）

> **2026-08-11 更正。** 本节初稿断言「AVA 无法解密 SDA 加密的 maFile，需要从零
> 实现」。**那是错的。** 当时 grep 的是 `app/lib/src/core/ma_file*.dart`，那个
> glob 不进 `crypto/` 子目录，于是漏掉了 `core/crypto/ma_file_crypto.dart`——
> 「我的检查看不见」被当成了「东西不存在」，与 CLAUDE.md 里记着的 dex/mapping
> 误判是同一个错误。原文保留在 git 历史里。

### 已经有的

- **`app/lib/src/core/crypto/ma_file_crypto.dart`** 与 SDA 的 `FileEncryptor.cs`
  逐字节兼容：PBKDF2-HMAC-SHA1 / 50000 轮 / 32 字节密钥 / AES-256-CBC / PKCS7，
  错密码返回 `null` 而不抛异常（照抄 C# 行为）。还带一个 isolate 批量解密
  （`decryptBatch`），避免 50000 轮推导卡住 UI 线程。
- **`app/test/core/ma_file_crypto_test.dart`** 用 **RFC 6070 官方向量**锁死
  PBKDF2 输出，另覆盖往返、错密码、salt/iv 长度、Unicode。
- **AVA 自己的账户库就是 SDA 的 maFiles + `manifest.json` 格式**：
  `services/account_store.dart` 读写带 `encryption_salt` / `encryption_iv` 的
  manifest，换密码时逐条重加密。

所以「移植解密」这件事**不存在**，早就完成了。

### 真正缺的

**导入流程。** `app/lib/src/ui/import_helper.dart:31` 拿到文件立刻
`jsonDecode(contents)`——SDA 加密的 maFile 是一段 **base64 密文，不是 JSON**，
到这行直接抛异常。整个流程也没有任何地方向用户要 SDA 的 passkey。

### 一个决定形态的格式约束

**salt 与 IV 不在 maFile 内部，在 `manifest.json` 的对应 entry 里**
（`ManifestEntry.encryption_salt` / `encryption_iv`，每个账户各一份）。

推论：**单独导入一个加密的 `.maFile` 在格式上不可能**——没有 manifest 就没有
参数。所以「读源目录的 manifest.json / 支持整目录导入」不是锦上添花，是这条路
唯一可行的形态。当前 UI 是 `openFile()` 选单个文件，得改成选目录
（或接受用户同时提供 manifest）。

### 权威规格（2026-08-11 从 SDA 源码核对）

`Jessecar96/SteamDesktopAuthenticator` → `FileEncryptor.cs` / `Manifest.cs`：

| 项 | 值 |
|---|---|
| KDF | PBKDF2-**HMAC-SHA1**（`Rfc2898DeriveBytes` 在 .NET 上默认 SHA1） |
| 迭代 | **50000** |
| Salt | 8 字节，base64，在 manifest entry |
| Key | 32 字节 |
| 模式 | AES-256-**CBC** + PKCS7 |
| IV | 16 字节，base64，每条 entry 独立 |
| 密文 | 整个 maFile 文件即一段 base64 |

> **坑**：`FileEncryptor.cs` 的类注释写着「100k rounds of PBKDF2」，而常量是
> `PBKDF2_ITERATIONS = 50000`。以常量为准。照注释实现会得到一个永远解不开的
> 实现——这也是为什么规格要从源码读，不从别人的描述读。

### 验收要求

不能只测「能导入」。至少覆盖：加密目录 + 正确口令、错误口令（必须给可读错误，
不是崩溃或静默失败）、manifest 缺失、manifest 里列的文件在目录中不存在、
entry 缺 salt 或 iv、以及**明文单文件导入仍然照常工作**（回归）。

---

## P1 · 代理支持

NebulaAuth 的卖点之一：「**Proxy support** in all account work processes」。

AVA 现状：搜 `proxy` 只有 `home_screen.dart:755` 的 `proxyDecorator`——那是
`ReorderableListView` 的参数，与网络无关。**没有任何代理能力。**

对 AVA 双重相关：

- 大陆用户连 Steam
- 跑 ArchiSteamFarm 的人给不同账户绑不同代理——而这批人正是 AVA 自我定位的
  核心人群（见 `posts/en/reddit-2026-08/`）

**需要先想清楚的**：代理是全局一个，还是每账户一个？后者才是 ASF 人群要的，
但会牵动账户模型与 maFile 往返（代理配置不属于 maFile 标准字段，不能塞进去
污染导出）。

---

## P1 · 账户分组 / 收藏 / 搜索 / 排序

- NebulaAuth：「**Mafile grouping** for improved management」
- SDA++ Mobile：「favorites, sorting, and search」

AVA 现在是一个可拖拽排序的平铺列表。账户一多就不够用——而「主号 + 小号 +
区域号 + 几个机器人」正是所有推广稿里写的场景，列表撑不住这个故事。

---

## P2 · otpauth 二维码导出

steamguard-cli：「QR code generation for importing 2FA secrets into other
applications, like KeeWeb」。

AVA 能导出 maFile，但没有二维码。`otpauth_uri` 在
`ma_file_normalizer.dart:20` 只作为**导入**时识别的键名出现，没有导出路径。
成本低，且强化「数据不锁死在我这」这条已经在讲的主张。

---

## P2 · 桌面自动更新

NebulaAuth：「Auto-update with SHA256 checksum verification, changelog viewer
and flexible update options」。

AVA 现状：`app/lib` 与 `installer/lib` 里搜 `updater` / `checkForUpdate` /
`autoUpdate`，**零命中**。桌面用户装完之后没有任何途径知道有新版本。

注意这条和站点那边的坑是同一类问题：`site.ts` 的下载链接曾经停在 v0.80.1 达
九个版本没人发现。分发链路上「不会自己报错的陈旧」是这个项目的惯犯。

---

## P2 · Steam Guard 备份码引导

SDA 的 README 专门教用户去
`store.steampowered.com/twofactor/manage` → Get Backup Codes 并打印保存。

AVA 全程没提过备份码。它是撤销码之外的第二道保险，而 AVA 已经在
`backupReminderBody` 里教用户备份 maFile 和撤销码了——少了这一条。

---

## 有意不跟的

**NebulaAuth 的后台自动确认交易**（「Automatic confirmations of trades/market
actions to save time」）。

AVA 有 `settingsAutoConfirmMarket`，但它自己的说明就写着「**它不会在后台确认
任何东西**」，只是上架时预勾选确认框。后台自动批准交易恰恰是让验证器变成风险
源的那类功能，与 AVA「所有不可逆操作都要长按」的设计直接冲突。

**这是分歧，不是差距。** 将来有人提 issue 问为什么没有，答案在这里。

---

**steamguard-cli 的「memory-clearing data structures to prevent leaking
secrets」** 在 Flutter 上基本做不到：Dart 的 `String` 不可变、GC 会复制对象，
没有可靠的清零手段。可以在 `Uint8List` 层面做有限的覆写，但不能对外承诺
「密钥不驻留内存」——那会是一句无法兑现的话。

---

## 情报（不是待办）

**YifePlayte/SteamGuardDump**（333★）是个 Xposed 模块，功能是从官方 Steam App
里把令牌数据抠到剪贴板，需要 root。不值得借鉴，但 333 颗星说明「我想把密钥从
官方 App 里弄出来」的需求量级——而 AVA 用官方迁移接口正大光明地做同一件事，
还不触发 15 天交易冷却。这个对比适合写进推广文案。
