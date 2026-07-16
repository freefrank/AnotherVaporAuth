# Paywall 前置事项 — 详细操作指南

日期:2026-07-16 · 面向:用户(全部需要账号权限,代码侧已就绪) ·
对应计划:`2026-07-15-paywall-android.md`

## 总览:六件事、产出什么、回填到哪

| # | 事项 | 产出 | 回填位置 |
|---|---|---|---|
| 1 | Play Console 订阅商品 | 商品 ID(已定 `ava_pro_monthly`) | 无需改代码(与 `play_channel.dart` 常量一致即可) |
| 2 | Google Cloud SA + OAuth | SA 邮箱/JSON 密钥、Web client_id | worker secrets;`kGoogleServerClientId` |
| 3 | AdMob | App ID、横幅/激励视频两个单元 ID、SSV 回调 | `src/play/AndroidManifest.xml`;`play_channel.dart` |
| 4 | 爱发电 | user_id、API token、plan_id、主页 URL | worker secrets;`paywall_screen.dart` 的 `kAfdianPageUrl` |
| 5 | Cloudflare worker 部署 | D1/KV id、Ed25519 公钥、api 子域 | `wrangler.jsonc`;`kEntitlementPublicKeyB64` |
| 6 | 内测名单 | 终身码清单(入 D1) | 无需改代码 |

**建议顺序**:3(AdMob,审核最慢,当天就提)→ 2(SA 授权生效有滞后)→
1、4 随时 → 5(依赖 2/4 的密钥,且要在 3 的 SSV 回调配置前上线)→ 6(依赖 5)。

---

## 1. Play Console:订阅商品

1. 进 [Play Console](https://play.google.com/console) → AVA(`pro.dotslash.ava`)→
   **创收(Monetize)→ 商品 → 订阅** → 创建订阅。
2. 商品 ID 填 **`ava_pro_monthly`**(必须逐字符等于
   `app/lib/src/services/play_channel.dart` 的 `kPlaySubscriptionProductId`,
   创建后不可改)。名称随意(如 "AVA Pro")。
3. 添加**基础方案(base plan)**:ID 建议 `monthly`,自动续订,账单周期 1 个月;
   定价以美区 **$0.99** 为基准,"按当前汇率设置所有地区价格",过一遍高税率
   国家的含税价是否难看。
4. **激活**商品与基础方案。
5. 注意两件事:
   - 订阅商品要能被客户端查询,**必须先往任一测试轨道上传一个带 BILLING
     权限的构建**(billing-ktx 8.0 会自动 merge 权限)——即 0.90 的 play
     flavor AAB 上传内测轨道后,沙盒才能跑通;
   - **许可测试**:Play Console 首页 → 设置 → 许可测试,把你自己的 Google
     邮箱加进去——这些账号购买不扣真钱,退订即时生效,联调全靠它。

## 2. Google Cloud:Service Account + Play API + OAuth client

worker 验 purchaseToken 和 Google 登录都靠这一步。

1. [console.cloud.google.com](https://console.cloud.google.com) 新建项目
   (如 `ava-entitlement`;复用旧项目也行)。
2. **启用 API**:API 与服务 → 库 → 搜 "Google Play Android Developer API"
   → 启用。
3. **Service Account**:IAM 与管理 → 服务账号 → 创建(名 `ava-worker`)→
   不用授予项目角色 → 创建后进"密钥"页 → 添加密钥 → JSON,下载。
   - JSON 里的 `client_email` → worker secret `GOOGLE_SA_EMAIL`;
   - 整个 JSON(或其 `private_key`,看 README 约定)→ `GOOGLE_SA_KEY`。
4. **Play Console 授权 SA**:Play Console → 用户和权限 → 邀请新用户 →
   填 SA 邮箱 → 账号权限至少勾 **"查看应用信息"+"查看财务数据"**
   (订阅状态查询需要财务权限),范围限定 AVA 一个应用即可。
   授权生效可能滞后几分钟到几小时,期间 API 回 401/403 不要慌。
5. **OAuth 同意屏幕**:API 与服务 → OAuth 同意屏幕 → External,scope 只要
   默认的 email/profile/openid;**发布状态改成"正式(In production)"**,
   否则 refresh 七天失效、且登录弹"未验证应用"警告。
6. **OAuth 客户端**(API 与服务 → 凭据 → 创建凭据 → OAuth 客户端 ID),要建**两个**:
   - **Web 应用**类型:名 `ava-entitlement-web`。它的 client_id 就是
     `kGoogleServerClientId`(`play_channel.dart`)和 worker secret
     `GOOGLE_CLIENT_ID`——Credential Manager 的 `serverClientId` **必须是
     Web 类型**,这是最容易踩的坑;
   - **Android** 类型:包名 `pro.dotslash.ava`,SHA-1 要登记**两个**:
     上传密钥的(`keytool -list -v -keystore ~/ava-upload.jks | grep SHA1`)
     和 Play 应用签名的(Play Console → 设置 → 应用完整性 → 应用签名页
     抄 SHA-1)。缺后者,商店分发版登录必失败。

## 3. AdMob

1. [admob.google.com](https://admob.google.com) 用同一 Google 账号开户;
   新账号有审核期(数天),**先提交,期间客户端继续用测试 ID 开发**。
2. 应用 → 添加应用 → Android → "是,已在应用商店上架" → 搜 AVA 关联
   (内测轨道搜不到就选"未上架",上架后再关联)。
3. 拿到 **App ID**(`ca-app-pub-XXXXXXXX~YYYYYYY`,注意是波浪号)→ 替换
   `app/android/app/src/play/AndroidManifest.xml` 里的测试 App ID。
4. 建**两个广告单元**(应用 → 广告单元 → 添加):
   - **横幅**:格式选 Banner(自适应锚定即默认)→ 单元 ID 回填
     `play_channel.dart` 的 `kBannerAdUnitId`;
   - **激励**:格式 Rewarded → 奖励可随便填(奖励实际由 worker 定)→
     单元 ID 回填 `kRewardedAdUnitId`。
5. 激励单元 → 高级设置 → **服务器端验证(SSV)** → 回调网址填
   `https://api.ava.dotslash.pro/v1/admob/ssv`(所以 worker 要先上线,
   或先填好等 worker 部署)。
6. **app-ads.txt**:AdMob 会给一行
   `google.com, pub-XXXXXXXX, DIRECT, f08c47fec0942fa0`——放到
   `ava.dotslash.pro` 站点根路径 `/app-ads.txt`(Pages 项目加个静态文件),
   AdMob 后台等它爬到并显示"已验证"。
7. 付款信息 + 身份验证尽早填($100 起付,验证拖着会限流)。

## 4. 爱发电

1. 创作者主页建**方案**:¥5/月(月度连续赞助档)。主页 URL
   `https://afdian.com/a/<你的slug>` → 回填 `paywall_screen.dart` 的
   `kAfdianPageUrl`(当前占位 `/a/dotslash`)。
2. **开放平台**:创作者后台 → 开发者(afdian.com/dashboard/dev)→ 拿
   **user_id** 与 **API token** → worker secrets `AFDIAN_USER_ID` /
   `AFDIAN_TOKEN`。
3. 方案的 **plan_id**:开发者文档的方案查询接口或方案编辑页 URL 里取 →
   `AFDIAN_PLAN_ID`(worker 用它拒绝非 ¥5 档订单)。
4. **Webhook**:开发者页配置回调地址
   `https://api.ava.dotslash.pro/v1/afdian/webhook`(worker 上线后配)。
5. ⚠ 上线前核验(worker README 的 TODO):用一笔真实小额订单对照
   query-order 返回字段(`status`、`out_trade_no`、`month`)与 sign 拼接
   顺序——worker 的实现按公开文档写成,**未经真实 API 验证**。

## 5. Cloudflare:worker 部署

完整命令在 `infra/entitlement-worker/README.md`,这里是流程骨架:

1. `cd infra/entitlement-worker && npm install`;
2. `npx wrangler d1 create ava-entitlement` 和
   `npx wrangler kv namespace create CONFIG` → 把两个 id 填进
   `wrangler.jsonc` 的占位符;
3. `npx wrangler d1 migrations apply ava-entitlement --remote`;
4. **生成 Ed25519 密钥对**(README 有 openssl 命令):
   - 私钥(base64 pkcs8)→ `npx wrangler secret put ENTITLEMENT_SIGNING_KEY`;
   - 公钥(32 字节 base64)→ 回填客户端
     `app/lib/src/services/entitlement_store.dart` 的
     `kEntitlementPublicKeyB64`。**私钥不落仓库、不进对话**,与
     ava-upload.jks 同等级对待,ownCloud 备份;
5. 其余 secrets:`AFDIAN_USER_ID`、`AFDIAN_TOKEN`、`AFDIAN_PLAN_ID`、
   `GOOGLE_SA_EMAIL`、`GOOGLE_SA_KEY`、`GOOGLE_CLIENT_ID`、
   `PLAY_PACKAGE_NAME=pro.dotslash.ava`;
6. KV 里可选写 `VIP_DAYS`(缺省 3);
7. **自定义域**:worker → Settings → Domains & Routes → 加
   `api.ava.dotslash.pro`(zone 已在 CF)。注意:此前记录过本账号
   workers.dev 子域有故障,**必须走自定义域**;
8. `npm run deploy` → 冒烟:
   `curl -X POST https://api.ava.dotslash.pro/v1/vip/claim -d '{"device_id":"x","device_class":"android"}'`
   期待 `404 {"error":"no_vip"}`;README 还有一条 workerd 上验证 Ed25519
   JWK 导出的冒烟项。

## 6. 内测名单 → 终身码

1. 名单来源:Play Console → 测试轨道的测试人员邮箱列表,加上当时招募帖
   /私信收集的表(`posts/zh/recruit/` 有发信脚本可比对);
2. 每人生成一个终身码插入 D1 `beta_testers`(README 有 SQL 示例;码用
   `openssl rand -hex 8` 一类生成即可);
3. 发码:可改造 `posts/zh/recruit/send_beta_invite.py` 群发;
4. 注意 worker 语义:**一码绑定首个兑换设备**,换设备需后台清
   `redeemed_by`(或将来加自助解绑)——发码邮件里提醒一句"在常用手机上兑换"。

---

## 全部占位符回填清单(代码侧)

| 常量 | 文件 | 来源 |
|---|---|---|
| `kEntitlementPublicKeyB64` | `app/lib/src/services/entitlement_store.dart` | 第 5 步密钥对 |
| `kEntitlementApiBase` | 同上(已填 `api.ava.dotslash.pro`,如换域名要改) | 第 5 步 |
| `kGoogleServerClientId` | `app/lib/src/services/play_channel.dart` | 第 2 步 Web client |
| `kBannerAdUnitId` / `kRewardedAdUnitId` | 同上 | 第 3 步 |
| AdMob `APPLICATION_ID` | `app/android/app/src/play/AndroidManifest.xml` | 第 3 步 |
| `kAfdianPageUrl` | `app/lib/src/ui/paywall_screen.dart` | 第 4 步 |
| `wrangler.jsonc` D1/KV id | `infra/entitlement-worker/` | 第 5 步 |

回填全部完成前,app 的行为是安全降级:公钥为空 → 所有 token 验签失败 →
永远免费版;Google client 为空 → 订阅流程报"该构建尚未配置";广告走
Google 官方测试位。也就是说**可以随时发 0.90 内测,后端就绪一项亮一项**。
