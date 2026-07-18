# 交易报价 + 家庭组 — 设计文档

日期：2026-07-15 · 状态：已与用户确认 · 布局仅针对手机版（桌面沿用现有响应式基架，不做专门优化）

> **2026-07-18 变更**：家庭组**邀请**已从待办中心的第三页签**移入家庭组信息页**
> （账户长按菜单 → 家庭组）；待办中心因此降为**两页签**（确认 / 报价）。邀请的
> 发现 / 预检 / 长按加入 / 2FA 联动逻辑不变，只是承载屏幕从 `FamilyInvitesTab`
> 并入 `FamilyGroupScreen`。下文凡提"邀请页签 / 三页签"按此更新理解。相关：
> `docs/specs/2026-07-18-device-sessions-design.md`（同批账户长按菜单改造）。

## 背景与目标

AVA 目前只能对交易/市场行为做 mobileconf 确认，看不到交易报价本身；家庭组邀请只会以
"未知类型确认"出现。本设计新增：

1. **交易报价**：查看收到/发出的报价与历史，就地接受/拒绝，接受后与 mobileconf 确认闭环；
2. **家庭组**：主动发现邀请、加入前预检、应用内完成加入 + 2FA 确认、只读信息页；
3. **确认类型补全**：mobileconf type 11（家庭组加入）、type 9（API Key 创建）等给出明确标签。

购买审批（家长批准儿童购买请求）为**二期**，本版只在信息页占位。

## 信息架构（已确认的决策）

- **待办中心**：现有确认页升级为三页签 —— `确认 / 报价 / 邀请`，各自带未处理角标；
  左右滑切换。入口不变（账户行右滑、桌面右键菜单），文案"确认"改为"待办"。
- **报价页签**：顶部分段器 `收到(n) | 发出(n) | 历史`。页签角标只计"收到"的待处理数。
- **报价卡片**：可展开卡，就地操作（方案 C）：
  - 收起态：头像 + 昵称 + 时间 + 一行摘要（`收 6 件 · 给 1 件`，🎁 赠送 / ⚠ 不对等标记）；
  - 展开态：双方物品缩略图网格（`↓ 收到` / `↑ 给出` 两行，稀有度用边框色，点缩略图看物品名），
    警告条，`拒绝` / `接受` 按钮；
  - **接受 = 长按 ~1 秒**：环形进度走完生效，期间以递减间隔触发
    `HapticFeedback.lightImpact`（逐渐加速的震动），完成时 `mediumImpact`；拒绝直接点。
  - 接受成功后自动滑到"确认"页签完成 mobileconf（type 2）。
- **邀请页签**：家庭组邀请卡 —— 组名/邀请人/角色/空位 + **加入前预检**
  （钱包地区、IP 匹配、一年冷却警告；钱包地区不符标红并禁用加入钮）。
  加入同样长按 + 加速震动 → 自动滑到"确认"页签完成 type 11 确认 →
  卡片变为"已加入 ✓ 查看家庭组 ›"。
- **家庭组信息页**：从邀请卡或账户操作单进入。首版只读：成员列表（角色标注）、
  空位/共享游戏数/冷却天数摘要行、"待处理"区（购买审批占位）、页底危险区"退出家庭组"（二期）。

## 协议层

### TradeOffersClient（新，`core/protocol/trade_offers_client.dart`）

| 操作 | 端点 | 风险档 |
|---|---|---|
| 报价列表/详情/计数/历史 | `IEconService/GetTradeOffers, GetTradeOffer, GetTradeOffersSummary, GetTradeHistory`（GET + `access_token`，JSON，`get_descriptions=1` 带物品描述） | A：官方文档化 |
| 拒绝收到 / 取消发出 | `IEconService/DeclineTradeOffer, CancelTradeOffer`（POST）；若 access_token 鉴权不通过则回退社区端点 `/tradeoffer/<id>/decline` | A / B |
| 接受报价 | `POST steamcommunity.com/tradeoffer/<id>/accept`，带 `steamLoginSecure` cookie、`sessionid`、`partner`、Referer；响应可能含 `needs_mobile_confirmation` | B：非公开但十年稳定（node-steam-tradeoffer-manager 同款） |

新模型 `core/models/trade_offer.dart`：`TradeOffer`（id、partner、方向、状态、双方资产、
时间、是否赠送、`escrow` 预估）+ `TradeAsset`（appid/contextid/assetid/数量 +
描述引用：名称、图标 URL、`name_color`/边框色、可交易性）。

注意：`GetTradeOffers` 的描述数组与资产按 `classid+instanceid` 关联；图标走现有
`ImageDiskCache`。物品估价（市场价）**不在**本版范围。

### FamilyGroupsClient（新，`core/protocol/family_groups_client.dart`）

均为 `IFamilyGroupsService` protobuf 调用（`callProtobuf` + access_token，风险档 B：
webui dump、官方客户端自用）：

- `GetFamilyGroupForUser`（`pending_group_invites`、当前组、角色、冷却）——邀请页签数据源；
- `GetInviteCheckResults`（钱包地区/IP/加入限制）——邀请卡预检；
- `JoinFamilyGroup(family_groupid, nonce)` → 触发 2FA（响应 `two_factor_method`）→
  mobileconf 出现 type 11 确认 → 待办中心"确认"页签接受；`ConfirmJoinFamilyGroup`
  是否必须调用**待真机联调确认**（debug log 抓官方 App 行为对照）；
- `GetFamilyGroup`（成员、空位、冷却）——信息页数据源。

字段号以 SteamDatabase/Protobufs `webui/service_familygroups.proto` 为准，按现有风格
在 client 内硬编码字段号并注释 proto 名。

### ConfirmationsClient（改）

`ConfirmationType` 新增：`familyJoin(11)`、`apiKey(9)`、`phoneChange(5)`、
`accountRecovery(6)`、`featureOptOut(4)`；UI chip 配色与 en/zh 标签。旧的
`1/2/3` 映射不变。

## 服务与状态

- 待办中心三页签共用账户会话；沿用现有 `ConfirmationAuthException` → 重登流程。
  报价/家庭组调用遇 401/eresult!=1 时同样引导会话刷新（复用 `session_manager`）。
- 角标计数：进入待办中心时并发拉三源（`getlist`、`GetTradeOffersSummary`、
  `GetFamilyGroupForUser`）；任一源失败只影响自己页签（页签内错误态 + 重试），不阻塞其他页签。
- 所有新请求走 `SteamApiClient`，自动进 debug log。

## 错误与边界

- 报价含 escrow（暂挂）时在展开卡黄条提示"对方无令牌守护，接受后物品将暂挂 N 天"；
- 赠送报价（只收不给）显示 🎁 但**不弱化**长按接受门槛（钓鱼报价常伪装赠送）；
- "你给出但一无所获"显示红色警告条；
- 接受返回 `needs_mobile_confirmation=false`（无需确认）时直接标记完成，不跳确认页签；
- 家庭组预检 `join_restriction` 非零 → 加入钮禁用并显示 Steam 原因文案；
- 断网/超时：页签级错误卡 + 重试按钮，与市场页现有模式一致。

## 统一长按确认与设置开关（2026-07-15 追加，已与用户确认）

- **统一范围（全面统一）**：所有不可逆的"接受类"操作共用同一个 `HoldToConfirmButton`
  组件与行为——报价接受、家庭组加入（计划 2）、确认卡单条 ✓（圆形图标变体）、
  "全部接受"（长按即二次确认，移除原弹窗）。拒绝/取消类操作保持直接点按；
  "全部拒绝"保留弹窗。
- **设置新增两个开关**（默认全开，持久化到 `app_settings.json`，provider 沿用
  skin 的 Notifier 模式）：
  - **长按确认**（`hold_confirm`）：关闭后单条接受退回普通点按（用户主动放弃
    安全门槛换速度）；批量"全部接受"退回弹窗二次确认作为安全底线；
  - **震动反馈**（`haptics`）：控制全 App 触觉反馈——长按 tick 与完成 impact、
    以及 home_screen 现有的 selection/medium impact 调用点。

## i18n / 测试 / 验收

- 新增 en/zh ARB 字符串（待办、报价、邀请、预检、警告文案等）。
- 单元测试：`GetTradeOffers` JSON fixture 解析（含描述关联、赠送/不对等判定、escrow）、
  `ConfirmationType` 新映射、FamilyGroups protobuf 编解码往返、长按计时器逻辑（seam 注入）。
- UI 冒烟：待办中心三页签渲染、报价卡展开/收起。
- 真机联调清单（AVD `ava_test` mock 账户 + 真实账户只读验证）：
  报价拉取/接受/拒绝闭环、type 11 确认出现与接受、`JoinFamilyGroup` 全流程、
  `ConfirmJoinFamilyGroup` 是否必需、DeclineTradeOffer 的 access_token 鉴权是否可用。

## 明确不做（本版）

桌面布局优化、物品市场估价、购买审批实装、退出/管理家庭组、全局跨账户待办聚合（方案 C，
结构上已预留演进空间）、交易报价的创建/还价。
