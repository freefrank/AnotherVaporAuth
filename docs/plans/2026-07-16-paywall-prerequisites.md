# Paywall 前置事项 — 详细操作指南

日期:2026-07-16(当日进展已回填,见状态列) · 面向:用户 ·
对应计划:`2026-07-15-paywall-android.md`

## 总览:六件事、产出什么、状态

| # | 事项 | 产出 | 状态(2026-07-16) |
|---|---|---|---|
| 1 | Play Console 订阅商品 | 商品 ID(已定 `ava_pro_monthly`) | 🔶 AAB v34(0.90.0)已发内测轨道,建品入口已解锁;**商品待创建** |
| 2 | Google Cloud SA + OAuth | SA 邮箱/JSON 密钥、Web client_id | ⏸️ **挂起**(2026-07-18 决定,恢复时从 §2 继续;仍是订阅购买链路的唯一阻塞项) |
| 3 | AdMob | App ID、两个单元 ID、SSV 回调 | ✅ 开户+建应用+双单元完成,真实 ID 已回填;app-ads.txt 双域上线;SSV 回调探测已修(worker 侧),后台保存待确认 |
| 4 | 爱发电 | user_id、token、plan_id、主页 URL | ✅ secrets 已入 worker,sign 算法已实测核验,主页 URL 已回填;webhook 测试推送已修通,**后台保存待确认**;首笔真实订单联调待做 |
| 5 | Cloudflare worker 部署 | D1/KV id、Ed25519 公钥、api 子域 | ✅ **已上线** `api.ava.dotslash.pro`,beta 码全链路验签通过;私钥备份于 ownCloud 根 `ava-entitlement-signing.pem` |
| 6 | 内测名单 | 终身码清单(入 D1) | ⏳ 待名单导出后一条 SQL 插入 |

**剩余关键路径**:2(Google SA + OAuth)→ 回填 `kGoogleServerClientId` +
worker 三个 GOOGLE secrets → Play 沙盒联调订阅;1(建订阅商品)随时可做;
4 的 webhook 在爱发电后台点"发送测试"通过后保存即可。

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

**时序说明(与应用发布状态的关系)**:开户、建应用、拿真实 ID **现在就能做**
("未上架"模式);但 AdMob 的应用审核、商店条目关联、app-ads.txt 验证要求
Play 商店页**公开可见**——内部/封闭测试不公开,**公开测试(open testing)
即可满足**,不必等正式发布。审核通过前真实单元 ID 无填充(横幅会自动收敛
为 0 高),功能联调不受影响。

1. [admob.google.com](https://admob.google.com) 用同一 Google 账号开户;
   身份验证/付款信息审核最慢,**现在就提交**。
2. 应用 → 添加应用 → Android → 选 **"未上架"** 先注册,立刻获得真实
   App ID 与单元 ID 提前回填;转公测后回来关联商店条目(触发应用审核)。
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

| 常量 | 文件 | 状态 |
|---|---|---|
| `kEntitlementPublicKeyB64` | `app/lib/src/services/entitlement_store.dart` | ✅ 已回填(生产公钥,2026-07-16) |
| `kEntitlementApiBase` | 同上 | ✅ `api.ava.dotslash.pro` 已上线 |
| `kGoogleServerClientId` | `app/lib/src/services/play_channel.dart` | ⏸️ **挂起,待第 2 步 Web client**(2026-07-18) |
| `kBannerAdUnitId` / `kRewardedAdUnitId` | 同上 | ✅ 真实 ID 已回填;**release 构建才用真实位,debug 恒走官方测试位**(防误点封号) |
| AdMob `APPLICATION_ID` | `app/android/app/src/play/AndroidManifest.xml` | ✅ 已回填 |
| `kAfdianPageUrl` | `app/lib/src/ui/paywall_screen.dart` | ✅ `ifdian.net/a/anothervaporauth` |
| `wrangler.jsonc` D1/KV id | `infra/entitlement-worker/` | ✅ 已填并部署 |

唯一剩余占位符是 `kGoogleServerClientId`:为空时订阅/恢复购买报"该构建尚未
配置",其余功能(含爱发电解锁、beta 码、激励视频)不受影响——安全降级仍然
成立,0.90 内测可以随时铺开。

**2026-07-18 挂起备注**:审计修复批(commit `1dd1929`)已把订阅流程改为
**先 Google 登录、后发起扣费**,且两条流程入口都有 `signInConfigured` 快速
失败——即使误上架未配置的构建,用户也只会看到"未配置"提示,**不可能被扣费
后拿不到权益**。恢复本项时只需:走 §2 建 Web client → 回填该常量 + worker
三个 GOOGLE secrets → Play 沙盒联调,代码侧无需再改。

## 关联完成项(2026-07-16,超出原六项范围)

- 隐私政策更新到 v2026-07-16(仓库 `PRIVACY*.md` + 站点 `/privacy`):新增
  AVA Pro(第 4 节)与广告(第 5 节)两节;
- 站点新增爱发电赞助区块(点击加载,守住零第三方请求承诺);
- 设置页新增 UMP"隐私选项"重开入口(仅 GDPR 地区且 required 时显示);
- worker 两处线上修复:AdMob SSV 校验请求(无 user_id → 200 零发放)、爱发电
  webhook 测试推送(无法核验 → `{ec:200}` 确认但零发放);
- Play Console 仍需(转公测前):应用内容 → 广告 / 广告 ID 两项声明、Data
  safety 表单更新、商店描述去掉"无广告"表述。

## 7. beta 码按类激活上线(2026-07-18 代码已就绪,待执行)

worker 已实现"一码四类端各一台"(commit `e77c3aa`,worker 测试 75 全绿):
同类换机为带上限替换(超限 `code_activation_limit`),新增
`POST /v1/entitlement/status` 供 app 展示各端激活状态。**执行顺序不可颠倒**
(新 worker 依赖新表;旧 worker 兼容新表,反向回滚安全):

1. **预检(只读)**——确认 50 个已发码无"半程失败"残留行:
   ```
   npx wrangler d1 execute ava-entitlement --remote --command "SELECT bt.code, bt.redeemed_by, e.id AS ent, d.device_class FROM beta_testers bt LEFT JOIN entitlements e ON e.channel='beta' AND e.subject=bt.code LEFT JOIN devices d ON d.entitlement_id=e.id WHERE bt.redeemed_by IS NOT NULL;"
   ```
   有 `redeemed_by` 但 `ent` 为空的行**无需处理**(新逻辑下任意设备兑换即自愈)。
2. `cd infra/entitlement-worker && npx wrangler d1 migrations apply ava-entitlement --remote`
   (纯增量建表 `activation_log`)。
3. `npm run deploy`——**已发行的 app 立即获得跨端兑换能力**(paywall 本来就能
   在第二台设备输码,只是不再收 `code_redeemed`)。
4. (可选)调参:`npx wrangler kv key put --binding CONFIG ACTIVATION_CAP 3` /
   `ACTIVATION_WINDOW_DAYS 90`(不设即用默认值)。
5. app 侧文案与状态卡已随批次 3 落库,随下个版本发布即可(纯锦上添花,不阻塞)。
