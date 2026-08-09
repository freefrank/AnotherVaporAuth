# 阮一峰《科技爱好者周刊》投稿

> **已提交 2026-08-09**：https://github.com/ruanyf/weekly/issues/11089
> 提交前查过该仓库 issue，无 AVA 记录，非重复投稿。

**提交方式**：GitHub issue，<https://github.com/ruanyf/weekly/issues>。
仓库首页原话是「欢迎投稿文章/软件/资源，请提交 issue」。**没有 issue 模板**，
自由格式；看最近的 issue，自荐惯例是标题带 `【开源自荐】` 前缀。

**写法**：短。周刊每条只有一段话加一张图，阮一峰会自己重写文案，
投稿写太长他也是删。给他一段能直接用的话、一个链接、一张图，就够了。

---

## 标题

```
【开源自荐】AVA：把多个 Steam 账户的令牌放进同一个列表，手机和桌面通用
```

## 正文

---

AVA（AnotherVaporAuth）是一个开源的 Steam 令牌验证器，Flutter 写的，一套代码出
Android / Windows / Linux / macOS 四个平台。

起因是官方 Steam App 一台手机只能装**一个**令牌。有小号、有区域账户、或者跑几个
ArchiSteamFarm 机器人的人，最后手里都是一堆 `.maFile` 备份加一个必须走到电脑前
才能用的桌面工具。AVA 把这些账户放进同一个列表：验证码、交易确认、登录批准、
交易报价、库存上架、远程注销其他设备，每个账户各自一份。

它直接读写老工具 SDA（Steam Desktop Authenticator）的 `.maFile` 格式，也能导入
Steam++ / Watt Toolkit 的导出文件，随时可以把 maFile 导出带走。另外它能把令牌
从官方 App 迁移过来——走的是官方 App 用的同一个接口，所以**不会触发 15 天交易
冷却**，而从网页移除令牌会。

密钥由 6 位 PIN 保护，存在设备硬件 Keystore 里，本地 AES-256-GCM 加密，验证码
完全离线生成。MIT 协议。

- 源码：https://github.com/freefrank/AnotherVaporAuth
- 官网 / 桌面版下载：https://ava.dotslash.pro
- Google Play：https://play.google.com/store/apps/details?id=pro.dotslash.ava

（利益相关：我是作者。Play 版有可选订阅解锁两套皮肤并去广告，免费版有横幅
广告；验证码、交易确认、maFile 导入导出这些在所有版本里都免费，也可以自己
编译一个完全不含广告与计费代码的版本。）

---

## 配图

`posts/shots-1.0.1/home-accounts.png`（账户列表）。周刊每条通常配一张图，
选信息密度最高、一眼能看出「多个账户在一个列表里」的那张。

## 备注

- **利益相关那段是有意留在正文里的**，不是免责声明模板。周刊读者对夹带私货
  敏感，主动写明作者身份和变现方式，比被读者在评论里指出来强。
- 没有写任何技术细节的展开（protobuf、R8 门禁那些）。周刊不是技术深度渠道，
  需要的人会自己点进仓库。
