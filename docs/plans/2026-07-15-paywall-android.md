# Paywall(Android)实施计划

日期:2026-07-15 · 对应 spec:`docs/specs/2026-07-15-paywall-design.md` ·
状态:草案,待用户复核后执行 · 目标版本:0.90.0(渠道拆分可先行落在 0.8x)

## 侦察结论(2026-07-15)

- `app/android/app/build.gradle.kts`:无 flavor;签名 fail-closed 守卫的正则
  `^bundle\w*Release$` 已天然兼容 `bundlePlayRelease`,不需改;
- CI(`.github/workflows/ci.yml`)只跑 `flutter analyze` + `flutter test`,
  Android 发布物**本地构建**落 `dist/`(upload key 只在本地),CI 不碰签名——
  拆 flavor 后 CI 保持不变,只需本地构建命令与 dist 命名跟进;
- `desktop-release.yml` / `windows-portable.yml` 挂起范围外,不动;
- 无任何既有 ads / billing / Google 登录依赖;设置持久化沿用
  `app_settings.json` + Notifier 模式(skin 先例);
- pointycastle 已在依赖中,含 Ed25519——`core/entitlement.dart` 验签无需新增
  crypto 依赖。

## 范围决策(2026-07-15 已与用户确认)

- **免费版主题只有黑/白**(`AvaSkin.none` + 深/浅色);现有 **neon、pixel
  两套皮肤进付费墙**,构成 Pro 主题包;
- **app 默认皮肤从 neon 改为黑/白**(`providers.dart` 现默认 neon);
  已在用 neon/pixel 且无 Pro 的老用户升级后回落黑/白(保留深浅色偏好)+
  一次性迁移提示;
- **桌面小组件延后到 1.0 之后**,与 paywall 首发无关;
- 激励视频 VIP 时长首发 **3 天**(服务端 KV 可配)。

## 前置事项(用户侧,可与开发并行)

1. Play Console:创建订阅商品 `ava_pro_monthly`($0.99/月,含税区定价核对);
2. Google Cloud:service account + Play Developer API 授权(worker 验
   purchaseToken 用);Android OAuth client(Google Sign-In 用);
3. AdMob:开户、建应用、两个版位 ID(banner / rewarded)、开启 rewarded 的
   playable 创意;`ava.dotslash.pro` 挂 `app-ads.txt`;
4. 爱发电:开放平台 API token;确认 ¥5/月 方案的 plan_id;
5. Cloudflare:worker 子域(建议 `api.ava.dotslash.pro`)+ D1 实例;
6. 内测名单:从 Play 测试轨道导出 Google 邮箱清单(whitelist 预载)。

## 任务分解

### Task 0:渠道拆分(先行,可独立提交进 0.8x)

- `build.gradle.kts`:`flavorDimensions += "channel"`;`productFlavors`
  `play` / `cn`,**applicationId 均保持 `pro.dotslash.ava`**,不设后缀;
- `app/android/app/src/play/AndroidManifest.xml`(新):AdMob
  `APPLICATION_ID` meta-data 等 play 专属声明的落点(Task 5 填充);
- `app/lib/src/core/channel.dart`(新):
  `const avaChannel = String.fromEnvironment('AVA_CHANNEL', defaultValue: 'cn')`
  + `enum AvaChannel { play, cn }` 解析;默认 `cn`(最小依赖面,忘传参也不会
  把广告代码当默认);
- 构建命令约定(写进 CLAUDE.md):
  - dev:`flutter run --flavor cn --dart-define=AVA_CHANNEL=cn`(模拟器默认);
  - 发布:`flutter build appbundle --flavor play --dart-define=AVA_CHANNEL=play`
    → `dist/AVA-v<版本>-play.aab`;`flutter build apk --flavor cn
    --dart-define=AVA_CHANNEL=cn` → `dist/AVA-v<版本>-cn.apk`;
- 测试:channel 解析单测;验收:双 flavor 均可 `flutter build apk --debug`,
  互相覆盖安装不丢数据(同包名同签名)。

### Task 1:entitlement worker(`infra/entitlement-worker/`,新)

- Cloudflare Worker + D1;表:
  `entitlements(id, channel, subject, pro_until, lifetime, revoked)`、
  `devices(entitlement_id, device_class, device_id, activated_at)`
  (`device_class ∈ {android, windows, linux, macos}`,每 entitlement 每类
  唯一——**四类端各一个名额,同类互踢**;0.90.0 仅 android 会被客户端使用)、
  `afdian_orders`、`beta_testers(email, code)`;
- 端点(全部返回/刷新 Ed25519 短期 token,24h 有效):
  - `POST /v1/play/verify`:Google id_token + purchaseToken + device →
    Play Developer API 校验订阅 → upsert entitlement(subject=Google sub);
  - `POST /v1/afdian/redeem`:订单号 + device → 爱发电订单查询 API 校验 →
    entitlement(subject=爱发电 user_id),订单号首绑即占用;
  - `POST /v1/afdian/webhook`:续订推送,延长 `pro_until`;
  - `POST /v1/token/refresh`:旧 token + device → 重验来源(play 重查订阅
    /afdian 查 `pro_until`)→ 新 token;device 名额被抢则 403(踢下线);
  - `POST /v1/beta/redeem`:永久解锁码 → lifetime entitlement;
  - `POST /v1/admob/ssv`:AdMob rewarded 服务端回调(SSV 签名校验)→
    给 device 发 3 天 VIP entitlement(时长存 KV 可配,首发 3 天);
- 密钥全走 worker secrets(Ed25519 私钥、爱发电 token、Google SA、SSV 公钥);
- vitest:各端点、订单重复绑定、同类设备互踢、SSV 验签、token 载荷。

### Task 2:`core/entitlement.dart`(纯 Dart,TDD)

- token(JWT,EdDSA)解析 + pointycastle Ed25519 验签(公钥编译期内置);
- 状态机:`pro(until)` / `grace(离线宽限 7 天)` / `free`;时钟回拨容忍
  (`iat` 超前本地 ±48h 判无效);
- 单测:验签正/反、过期、宽限边界、回拨、畸形 token 不崩。

### Task 3:`services/entitlement_store.dart` + provider

- token 持久化(沿用 storage_provider 路径,明文即可——token 本身有签名与
  设备绑定,不属机密);`device_id` 首启生成并持久化;
- 刷新调度:app 启动 + 24h 周期调 `/v1/token/refresh`;403(被踢)→ 清 token
  + 提示;网络失败→静默留在宽限期;
- `proProvider`(Notifier):UI 唯一消费面,`ProStatus { pro, vip, free }`;
- 单测:刷新成功/被踢/断网三路径(mock client)。

### Task 4:play flavor — Google 登录 + 订阅购买

- 依赖(仅 play flavor 编译面):`google_sign_in`、`in_app_purchase`;
  Dart 侧条件导入:`services/billing/billing_play.dart` ↔ `billing_stub.dart`
  (cn 构建物理不含实现,`avaChannel` gate 只是 UI 层开关);
- 流程:paywall 页购买 → Billing 拿 purchaseToken → Google 登录(未登录则
  引导)→ `/v1/play/verify` → token 落库;"恢复购买" = restorePurchases +
  重走 verify;
- 单测:billing 封装状态机(mock);真机项:沙盒 license tester 全流程。

### Task 5:play flavor — AdMob(横幅 + 激励视频 + UMP)

- `google_mobile_ads`;play manifest 填 APPLICATION_ID;
- UMP 同意流程先于任何广告加载(GDPR/US);
- 横幅:仅 `home_screen` 底部,自适应,`proProvider` 非 free 即不加载;
  离线/加载失败高度收敛为 0;含不可逆操作按钮的屏幕一律无广告(架构上
  banner 只存在于 home,天然满足);
- 激励视频:paywall 页 + 横幅角落"去广告"入口;完成后由 worker SSV 授予
  VIP,客户端轮询 refresh 拿到新 token(不信任客户端本地回调);
- 测试:测试广告位 ID 走 debug 构建;单测 gate 逻辑。

### Task 6:paywall UI + 设置入口 + cn 解锁

- `ui/paywall_screen.dart`:权益列表、价格、渠道分支(play:订阅+看视频;
  cn:爱发电引导 + 订单号输入)、内测解锁码入口(两渠道都有);
- 设置页"AVA Pro"区:状态(Pro/VIP 到期时间)、恢复购买(play)、
  换绑设备说明、订单号重输(cn);
- Pro 权益接线(主题):skin 选择器中 neon/pixel 对 free 用户显示锁标 +
  点击跳 paywall;`SkinController` 读取持久化值时校验 entitlement——无 Pro
  而存值为 neon/pixel 时回落 `none`(保留 `AvaBrightnessMode`)并弹一次性
  迁移提示;默认皮肤由 neon 改为 `none`;
- 单测:皮肤回落逻辑(有/无 Pro × 三种存值)、默认值变更;
- widget 冒烟:paywall 双渠道渲染、锁标跳转、订单号输入错误态、迁移提示。

### Task 7:l10n(en/zh ARB)

订阅/权益/解锁/被踢下线/广告同意/错误文案全量;沿用现有 ARB 流程。

### Task 8:公开材料(发布前 checklist,不进代码)

- 商店描述去掉"无广告"表述(play 免费态有横幅);
- 隐私政策新增:AdMob、UMP、Google 登录、entitlement 后端、爱发电订单校验;
- 发布公告:订阅制替代"一次性买断/兑换码"的变更交底 + 内测终身 Pro 兑现说明。

### Task 9:收尾

- `flutter analyze` 零问题 + `flutter test` 全绿(WSL 正本);
- cn 包验收:`apkanalyzer` 确认无 ads/billing/GMS 类;双 flavor 互升级不丢
  maFiles;
- 真机联调清单:play 沙盒订阅购买/退订降级、rewarded SSV 到账、cn 订单号
  真实小额验证、同类设备互踢、断网宽限、恢复购买。

## 执行顺序与依赖

Task 0 → 2 → 3 →(1 与 2/3 可并行)→ 4/5(依赖 1、3;彼此独立)→ 6(依赖
3/4/5)→ 7 → 9;Task 8 与开发并行、发布前完成。前置事项 1–6 在 Task 4/5/9
之前必须就绪。
