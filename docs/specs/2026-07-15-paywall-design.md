# Paywall(Pro 订阅)+ 渠道拆分 — 设计文档

日期:2026-07-15 · 状态:已与用户确认 · 目标版本:**0.90.0** 起 ·
**本版只做 Android;桌面端(Windows/Linux/macOS)整体挂起**,仅在 worker
架构上预留其设备名额与验证路径,不实现客户端

## 背景与目标

AVA 进入变现阶段。本设计覆盖:① Play 版与国内版的 build 渠道拆分(立即做);
② Pro 订阅与广告的商业模型;③ 付费身份(VIP)的多端同步架构(Cloudflare Worker
entitlement 服务);④ 对外承诺的核对与必须随发布更新的公开材料。

## 对外承诺核对(硬约束)

来源:内测招募帖 `posts/en/POST.md` / `posts/zh/recruit/POST.md`。

- **核心安全功能永久免费**:令牌验证码、交易确认、登录批准、maFile 导入导出
  ——永不进 paywall。本设计遵守。
- **内测用户终身 Pro**(含未来所有 Pro 功能)——必须实现,见 whitelist 节。
- **MIT 开源、自行 build 解锁不设防**——entitlement 校验只做"诚实用户的门",
  不搞 DRM 军备竞赛;代码里不做混淆对抗。
- **变更登记(需对外公告)**:招募帖承诺的是"一次性买断或看广告解锁 /
  直发版爱发电兑换码",现改为**订阅制**。正式发布公告必须显式说明这一变更
  ("提前交底"是信誉资产,变更也要交底)。同时需更新:
  - 商店描述(`store/*/full-description.txt`)"无广告、无追踪"表述(play 免费版将有广告);
  - 隐私政策 `ava.dotslash.pro/privacy`(新增:广告 SDK、Google 登录、entitlement 后端)。

## 商业模型(已确认)

| 渠道 | 价格 | 解锁方式 | 广告(免费态) |
|---|---|---|---|
| **play**(Google Play) | $0.99/月 | Play Billing 订阅 | 常驻横幅 + 激励视频(长视频)解锁 **3 天 VIP** |
| **cn**(GitHub 直发) | ¥5/月 | 爱发电月度赞助 → **订单号**在 app 内解锁 | **无广告**(广告 SDK 不进 cn 包) |

- **两渠道权益不互通**(用户确认:"国内和 play 不通用")。
- **按端分名额激活**(已确认):一份订阅在**手机(Android)、Windows 桌面、
  Linux、macOS 四类端各占一个名额**,即同一订阅最多四台设备同时激活、每类一台;
  同类端新设备激活即吊销该类旧设备 token(worker 侧按 `device_class` 记录
  active device)。**0.90.0 仅启用 `android` 名额**,其余三类是 worker 数据
  模型的预留,桌面客户端挂起。
- VIP(激励视频)期内权益 = Pro(含去横幅);到期回落免费态。

### 广告位分配(play 渠道免费态,已定)

| 版位 | 形式 | 位置与触发 | 定位 |
|---|---|---|---|
| 横幅 | AdMob 自适应 banner(~$0.1–1 eCPM) | **仅主屏(账户列表)底部**常驻;待办中心、确认/报价/邀请页、登录流、扫码页一律不出现 | 存在感与转化提醒,收入次要 |
| 激励视频 | rewarded(~$10–50 eCPM) | 用户主动触发:paywall 页"看视频得 3 天 VIP"按钮 + 横幅角落"去广告"入口 | 转化漏斗为主、收入为辅(3 天/次 ≈ 每用户每月最多 ~10 次,兼顾广告收益与订阅转化摩擦) |
| 插屏 / App Open | **不做** | — | 安全类 app 全屏广告的误触风险不可接受(确认/报价按钮邻近),且破坏"秒开取码"核心闭环;$4–15 eCPM 补不回卸载率 |
| Playable | 不单列 | — | playable 是广告**创意形式**而非发布方版位,在 AdMob 后台对 rewarded 版位开启即可承接其高 eCPM 需求 |

约束:横幅在离线/加载失败时高度收敛为 0(不留占位空洞);任何含不可逆操作
按钮的屏幕不渲染广告(误触即事故)。

### 聚合(mediation)策略

- **首发只接 AdMob 单网络**:AdMob 自身已通过 AdX 接入实时竞价需求,横幅与
  激励视频的 fill rate 和 eCPM 对小体量 app 足够;
- 待月广告收入上量(参考线:数百美元/月)再评估聚合——届时选 **bidding
  (实时竞价)而非手工 waterfall**(AdMob Mediation 或 AppLovin MAX),
  waterfall 需要人工调优出价序列,不适合无广告运营人力的项目;
- 登记代价:每多接一家网络 SDK,包体、启动耗时、隐私声明(Play Data safety
  + UMP 弹窗披露方)都要同步扩,与"隐私"卖点的冲突随之加深——上聚合前重新
  过一遍这笔账。激励视频解锁时长服务端可配,首发 3 天(2026-07-15 由 7 天
  调整:7 天/次会让月观看数压到 ~4 次,广告收益与订阅转化两头受损)。

## Pro 权益范围(0.90.0,已确认)

- **免费版主题只保留黑/白基础外观**(`AvaSkin.none` + 深/浅色模式);现有
  **neon、pixel 两套皮肤进付费墙**,连同后续新增主题构成 Pro 主题包。这与
  对外承诺不冲突——招募帖明确把"主题包"列为付费增值项,核心安全功能不受影响。
- 迁移行为:升级到 0.90.0 时,正在使用 neon/pixel 且无 Pro 的用户回落黑/白
  外观(保留其深浅色偏好),一次性提示"该主题已成为 Pro 权益"+ paywall 入口;
  **app 默认皮肤从 neon 改为黑/白**(当前 `providers.dart` 默认 neon,需同步改)。
- 0.90.0 Pro 权益 = Pro 主题包(neon/pixel + 后续新增)+ play 免费版去横幅;
  后续:云同步、交易通知等在线功能。
- **桌面小组件延后到 1.0 之后**,不在 paywall 首发范围。
- 免费版功能面 = 0.82.0 全部功能减 neon/pixel 主题(play 渠道另有一条横幅)。

## 渠道拆分(Task 0,立即做,先于其余一切)

- Android `productFlavors`:`play` / `cn`,**applicationId 不变**
  (`pro.dotslash.ava`,两渠道历史上就是同包名分发,升级路径不能断)。
- 依赖隔离:`google_mobile_ads`、Play Billing、`google_sign_in` 仅进 play flavor
  (flavor-specific 依赖 + Dart 侧条件导入);cn 包物理上不含广告/计费/Google 代码。
- Dart 侧渠道常量:`--dart-define=AVA_CHANNEL=play|cn`,封装为
  `core/channel.dart` 的编译期 const,保证 tree-shaking 掉另一渠道代码。
- CI / release:v tag 触发双产物——play AAB(上 Play)+ cn APK(上 GitHub
  Release);`dist/` 命名 `AVA-v<版本>-play.aab` / `AVA-v<版本>-cn.apk`。
- 桌面端:挂起,不拆 flavor 也不做解锁入口(后续恢复时:同一构建双入口
  ——Google 登录 / 爱发电订单号,无广告)。

## VIP 多端同步 — entitlement 服务(Cloudflare Worker)

### 架构

```
手机 play ──Billing purchaseToken──▶                  ◀──订单号────── 手机 cn
(桌面 ──Google OAuth loopback──▶ 挂起) CF Worker + D1 ◀──爱发电 webhook(续订)
                                        │
                              Ed25519 签发 entitlement token
                                        ▼
                    app 内置公钥离线验签;24h 刷新;离线宽限 7 天
```

- **Worker + D1**:表 `entitlements`(channel、subject、expiry、active_device、
  revoked)、`beta_testers`、`afdian_orders`。密钥(Ed25519 私钥、爱发电 API
  token、Google service account)全部走 worker secrets。
- **token**:短期(24h)Ed25519 JWT,载荷 `{channel, subject, pro_until,
  device_id}`;app 内置公钥**离线验签**,断网宽限 7 天后降级免费态。
  纯 Dart 实现在 `core/entitlement.dart`,重点单测对象。

### play 渠道流

1. Android:Play Billing 拿 `purchaseToken` → 上报 worker;
2. worker 用 Play Developer API(service account)校验订阅有效 → entitlement
   绑定用户 **Google 账户**(app 内 Google Sign-In 提供身份);
3. (挂起)桌面端:Google OAuth(desktop client,loopback 回环流)登录同一
   Google 账户 → worker 查 entitlement → 签发 token——worker 端点本版即按此
   形态设计(凭 Google 身份换 token),桌面客户端后续接入时无需改协议;
4. 续订/退订状态:首发用"按需重验 purchaseToken"(每次刷新时查),
   RTDN(Pub/Sub 实时通知)列为后续优化。

### cn 渠道流(用户确认:CF Worker + 订单号)

1. 用户在爱发电完成 ¥5/月 赞助 → 拿**订单号**在 app 内输入;
2. worker 调爱发电开放平台"订单查询"API 验证订单真实性与对应方案 →
   为该订单签发当月 entitlement,绑定首个激活设备;
3. **续订**:接爱发电 webhook,同一 user_id 的连续赞助自动延长已绑定的
   entitlement(用户无需每月重输);webhook 丢失时的兜底 = 输入最新订单号;
4. 订单号即凭证,**不建账户体系**(无邮箱/密码);换设备 = 在新设备重输订单号,
   旧设备被踢。

### 内测终身 Pro(whitelist)

- `beta_testers` 表预载内测名单(Play 测试轨道收集的 Google 邮箱);
- play 渠道:Google 登录邮箱命中 → 直接签发永久 entitlement;
- cn 渠道 / 不愿用 Google 登录者:按名单一对一发**永久解锁码**(worker 生成,
  一次性绑定设备,同样单设备策略)。

## 客户端改动面

| 位置 | 内容 |
|---|---|
| `core/channel.dart`(新) | 渠道编译期常量 |
| `core/entitlement.dart`(新) | token 模型 + Ed25519 验签 + 过期/宽限判定(纯 Dart) |
| `services/entitlement_store.dart`(新) | token 持久化、刷新调度、`proProvider`(Notifier 模式) |
| `services/billing/`(play flavor) | Play Billing 封装(订阅购买/恢复) |
| `services/ads/`(play flavor) | AdMob 横幅 + 激励视频封装、UMP 同意流程 |
| `services/google_auth/`(play flavor) | Google Sign-In(Android;桌面 loopback OAuth 挂起) |
| `ui/paywall_screen.dart`(新) | 订阅页:价格、权益列表、渠道对应解锁入口 |
| 设置页 | "AVA Pro" 入口(状态、恢复购买、订单号输入、设备管理) |
| worker(新仓或 `infra/`) | entitlement 服务(Worker + D1) |

## 错误与边界

- worker 不可达:已有 token 在宽限期内照常 Pro;宽限期尽头降级并提示;
- 爱发电订单号无效/方案不符/已被他人绑定:逐条明确错误文案;
- Play 订阅退款/到期:下次刷新降级;
- 激励视频加载失败:降级提示稍后再试,不阻塞其他路径;
- 时钟回拨:token 签发时间 sanity check(`iat` 晚于本地时间容忍 ±48h)。

## 风险登记

- **爱发电开放平台**的 API 配额/稳定性、webhook 可靠性——首发即备"手输最新
  订单号"兜底路径;
- Play Developer API 需要 service account 与 Play Console 授权,提前办;
- 激励视频经济性:单次 $0.01–0.04 vs 订阅 $0.99/月,3 天/次是收益与转化
  摩擦的折中——时长
  服务端可配,观察数据再调;
- AdMob 必须接 UMP(GDPR/美国州法同意弹窗),cn 包无此负担;
- "无追踪"卖点弱化是既定代价,公告里坦白说。

## i18n / 测试 / 验收

- 新增 en/zh ARB:paywall、订阅状态、订单号解锁、设备踢下线、广告相关文案。
- 单测:entitlement 验签/过期/宽限/时钟回拨、channel gate、订单号解锁状态机、
  billing mock 流;worker 侧订单验证与单设备互踢逻辑(vitest)。
- 真机:play flavor 走 Play 内购沙盒(license tester)+ 测试广告位;
  cn flavor 用真实爱发电小额订单验证全流程;双 flavor 安装包互升级不破数据。
- 验收:cn 包 `apkanalyzer` 确认无 ads/billing/GMS 依赖;两渠道权益互不可用。

## 明确不做(本版)

**桌面端全部(挂起)**:Windows/Linux/macOS 客户端的解锁入口、Google loopback
OAuth、桌面 Pro 界面——worker 数据模型与端点已预留,恢复时不动协议;
**桌面小组件(Android widget)**:延后到 1.0 之后;
iOS;一次性买断;渠道间权益互通;云同步/交易通知实装(只在 paywall 权益列表
预告);家庭共享订阅;自助退款;RTDN 实时通知(后续);广告聚合平台。
