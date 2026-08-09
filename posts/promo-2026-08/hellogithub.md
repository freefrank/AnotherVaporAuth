# HelloGitHub 月刊投稿

> **已提交 2026-08-09**：https://github.com/521xueweihan/HelloGitHub/issues/3523
> 提交前查过 issue 与月刊内容，均无 AVA 记录，非重复投稿。

**提交方式**：GitHub issue，模板 `submit-cn.yaml`（不是 PR，也不是邮件）。
入口 <https://github.com/521xueweihan/HelloGitHub/issues/new/choose> → 「提交项目」。
标题会自动带 `[开源推荐] ` 前缀。网站入口 <https://hellogithub.com> 也能提交。

**提交前先做**（模板末尾自己列的三条）：

1. 到 <https://hellogithub.com> 搜 `AnotherVaporAuth`，确认没被推荐过。
2. 读一遍[审核标准](https://github.com/521xueweihan/HelloGitHub/issues/271)。
3. **项目描述必须原创，不能复制 README。** 下面这份是重写的，不是抄的。

**自荐是允许的**，审核标准里对自荐项目单独放宽了 star 与 issue 活跃度的要求
（AVA 目前 7 star）。但它会看：文档是否完整、是否已用于生产、同类项目是否过多。
前两条 AVA 站得住；第三条要靠「多账户 + maFile 迁移」把自己和普通 2FA 应用区分开——
下面的亮点就是围绕这个写的。

---

## 字段

### 项目地址

```
https://github.com/freefrank/AnotherVaporAuth
```

### 类别

`其它` — 下拉框里没有 Dart / Flutter 选项。

### 项目标题（上限 50 字符）

```
一个能同时管多个 Steam 账户的开源令牌验证器，手机和电脑通用
```

### 项目描述（限 32–256 字符）

```
官方 Steam App 一台手机只能装一个令牌，于是有小号、有区域账户、有挂机机器人的人，手里最后是一堆 maFile 加一个要走到电脑前才能用的桌面工具。AVA 用 Flutter 把这件事重写了一遍：所有账户在同一个列表里，验证码、交易确认、登录批准、报价、库存上架都在，Android 与 Windows / Linux / macOS 共用一套代码。
```

### 亮点

```
- 直接读写老工具 SDA 的 .maFile（PBKDF2/SHA1 + AES-256-CBC），也吃 Steam++ / Watt Toolkit 的导出，迁移不用重新绑定；随时可以把 maFile 导出带走，不锁数据。
- 能把令牌从官方 Steam App 迁移过来，走的是官方 App 用的同一个接口，**不触发 15 天交易冷却**——而网页移除令牌会。这是同类工具里少有人做对的一件事。
- 交易确认走原生 JSON 解析，不套 WebView；报价会把双方物品都展开，接受前提示赠送 / 单方面 / Steam 保管期。
- 密钥由 6 位 PIN 保护、存在设备硬件 Keystore 里，本地 AES-256-GCM 加密；验证码完全离线生成，断网也出码。
- 一套 Dart 代码出四个平台的包，桌面版不是套壳网页。
- 所有不可逆操作（接受交易、加入家庭组）都要长按确认，不会因为手滑点一下就发生。

需要说明的是：Google Play 版有可选订阅（解锁两套皮肤、去广告），免费版会显示横幅广告。但验证码、交易确认、登录批准、令牌迁移、maFile 导入导出在所有版本里都免费。广告与计费依赖只挂在 play 这个 flavor 上，cn flavor 的包里根本没有编进去——不是运行时关掉的。
```

### 示例代码（可选，但这段能直接证明上面最后一句）

````markdown
Android 分了两个 flavor，广告与计费依赖只声明在 `playImplementation` 上，
所以 cn 渠道的包里这些类根本不存在，而不是运行时被关掉：

```kotlin
// app/android/app/build.gradle.kts
flavorDimensions += "channel"
productFlavors {
    create("play") { dimension = "channel" }
    create("cn")   { dimension = "channel" }
}

dependencies {
    "playImplementation"("com.android.billingclient:billing-ktx:8.0.0")
    "playImplementation"("com.google.android.gms:play-services-ads:24.4.0")
    "playImplementation"("com.google.android.ump:user-messaging-platform:3.2.0")
}
```

出包时用 R8 的 `mapping.txt` 卡一道，这三个包名在 cn 变体里必须为 0：

```sh
grep -cE "^com\.google\.android\.gms\.ads|^com\.android\.billingclient|^com\.google\.android\.ump" \
  app/build/app/outputs/mapping/cnRelease/mapping.txt
```
````

### 截图（可选）

上传 `posts/shots-1.0.1/` 里的账户列表与交易确认两张。

---

## 备注

- **付费档和广告写进了「亮点」的末尾。** HelloGitHub 收录的是开源项目，
  藏着变现只会在审核时被翻出来。主动说，并且把「核心功能全免费 + cn 包
  连代码都没编进去」这个可验证的事实一起给出，比不提有利。
- 类别选「其它」是没办法的事，下拉框里确实没有 Dart。
