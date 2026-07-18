# 设备管理 / 会话列表（Device Sessions）设计

- 状态：**已实现并合并**（2026-07-18）——设备列表 + 远程注销（revoke）均落地，
  revoke 签名已逆向 Steam APK 并在真机实弹验证通过。
- 来源：2026-07-18 内测 feature request——"设备管理，可以 revoke 某个设备的授权"。
- 相关：[roadmap] 的「设备管理 / 会话吊销」条目；协议基建同 `family_groups_client`；
  revoke 签名方案见 memory `steam-revoke-signature`。

## 目标

在按账户的动作菜单里新增「登录设备」入口，展示该 Steam 账户所有已登录的
设备 / 浏览器会话（名称、平台、最近活跃时间与大致地理位置），并标记「本机」。

**分期（均已完成）**：一期**只读列表**（`EnumerateTokens`）；二期**远程注销**
（`RevokeRefreshToken`）——其签名方案曾是唯一阻塞，逆向 Steam APK 得出并实弹
验证后落地，来龙去脉见 §Revoke。

## 协议事实（对照 SteamDatabase/Protobufs，verbatim 核实）

来源：`steam/steammessages_auth.steamclient.proto`（消息与字段号）、
`webui/service_authentication.proto`（RPC 的 `bConstMethod` / `ePrivilege` 注解，
决定 GET/POST）。

### `IAuthenticationService/EnumerateTokens`

- **HTTP：POST**。该方法**没有** `bConstMethod`（只有 `ePrivilege=1`）——
  与相邻的 `GetAuthSessionsForAccount`（`bConstMethod=true` → GET）**不同**。
  const 方法在 api.steampowered.com 上必须 GET、非 const 必须 POST（真机验证：
  搞反会被 405 拒）。故本调用用 `callProtobuf` 的默认 `useGet:false`。
- 需 access token（`ePrivilege=1`）。
- 请求 `CAuthentication_RefreshToken_Enumerate_Request`：
  - `1 include_revoked` (bool, 默认 false)。我们发**空 body**（= 只看未撤销的）。
- 响应 `CAuthentication_RefreshToken_Enumerate_Response`：
  - `1 refresh_tokens` — **repeated** `RefreshTokenDescription`
  - `2 requesting_token` (fixed64) — 调用方自己的 token_id（用来标「本机」）

`RefreshTokenDescription` 字段：

| # | 名称 | 类型 | 用途 |
|---|---|---|---|
| 1 | token_id | fixed64 | 设备/会话稳定 id（**无符号**解码，见下） |
| 2 | token_description | string | Steam 的人类可读设备名，可能为空 |
| 3 | time_updated | uint32 | 最近刷新时间（unix 秒） |
| 4 | platform_type | enum | 0 未知 / 1 SteamClient / 2 WebBrowser / 3 MobileApp |
| 5 | logged_in | bool | 是否仍在登录态 |
| 10 | last_seen | message | `TokenUsageEvent`：时间 + 大致地理 |

`TokenUsageEvent`（first_seen/last_seen 共用）：`1 time`、`4 country`、
`5 state`、`6 city`（`2 ip` 我们**丢弃**——粗粒度地名足够用户辨认，留 IP 无收益）。

**无符号 fixed64**：token_id 是个 64 位句柄、高位常置位。`ProtoField.asFixed64`
会把高位置位的值 sign-flip 成负 int，回传 Steam 就不对了。故 client 用
`_uFixed64` 从 8 个小端字节自行解码成**无符号十进制字符串**保存。
标「本机」用字符串等值比较（device.token_id == requesting_token）。

### `IAuthenticationService/RevokeRefreshToken`（二期）

- POST，`ePrivilege=2, eWebAPIKeyRequirement=1`。
- 请求 `CAuthentication_RefreshToken_Revoke_Request`：
  `1 token_id` (fixed64)、`2 steamid` (fixed64)、
  `3 revoke_action` (enum：0 Logout / 1 Permanent…)、**`4 signature` (bytes)**。
- **signature 已逆向 Steam APK 3.10.9 得出（2026-07-18，HIGH 置信度）**：

  ```
  signature = HMAC_SHA256(
      key = base64_decode(shared_secret),   // 密钥 = shared_secret 原始字节
      msg = ascii(token_id 的十进制字符串)    // 如 "123…789" 的 ASCII 数字，非 LE 整数
  )                                          // → 原始 32 字节
  ```

  与扫码批准签名（LE 整数拼接）**布局不同**，别照抄。msg 不含 steamid / 时间戳
  （无需时钟同步）；steamid、revoke_action 照放请求但不参与签名。证据链与坑见
  memory `steam-revoke-signature`。
- **已实弹验证通过（2026-07-18）**：AVA dev 包在真机对一次性小号 revoke 成功，
  目标设备真掉线、Steam 回 OK。token_id 十进制字符串形式的静态推定被证实，方案
  确认无误；二期 revoke 已落地（`SessionsClient.revoke` + 每设备注销按钮）。

## Revoke 签名的来龙去脉（已解决）

`signature` 是 "required signature over token_id"。一期动工时，**其 HMAC 密钥与被签
数据 Steam 未公开，也没有可靠的公开参考实现真正算过它**：

- **steamguard-cli** 只封装了 `revoke_refresh_token` 的 API 外壳，`src` 里**从未
  调用**；它的 `build_signature` 是给**扫码登录批准**用的
  （HMAC-SHA256 over `version‖client_id‖steam_id`），**不是** revoke 的签名。
- **node-steam-session** 未实现设备吊销；**ValvePython/steam** 只有 protobuf 定义。

按仓库红线（"protobuf 字段编号要对照 SteamDatabase 核实，不要照抄第三方"、
"成功信号别信 `success` bool"）——**签名方案没拍脑袋写**，而是逆向 Steam 官方
APK（3.10.9，Hermes HBC v96）得出上文的方案，再用一次性小号在真机实弹确认。
二期随即落地：`SessionsClient.revoke` + 每设备注销按钮 + 二次确认，且**禁止对
「本机」自注销**（会把自己登出）。

## 数据模型（`core/models/device_session.dart`）

- `DeviceSession`：token_id / description / timeUpdated / platformType /
  loggedIn / lastSeen。
- `DeviceUsage`：time / country / state / city，`locationLabel` 拼 "City, State, Country"。
- `DeviceSessionList`：devices + requestingTokenId，`isCurrent(d)` 判本机。

## Client（`core/protocol/sessions_client.dart`）

- `SessionsClient.enumerate(account)`：requireAccessToken → POST EnumerateTokens →
  解析 repeated + 嵌套 last_seen → 按 timeUpdated 降序 → 返回 `DeviceSessionList`。
- `SessionsClient.revoke(account, device, {permanent})`：算签名 → 组请求
  （token_id/steamid/revoke_action/signature）→ POST RevokeRefreshToken。token_id
  以无符号十进制字符串存，回写 fixed64 时 `BigInt.toSigned(64)` 复原低 64 位；
  成功 = OK eresult（空 body），不信 `success` bool。
- 会话过期由 UI 层 `fetchWithAutoRefresh` 续期重试一次（同待办页签 / family）。

## UI（`ui/device_sessions_screen.dart`）

每台设备一张 `AvaPanel`（平台图标 + 名称 + 「本机」/「已登出」角标 +
"平台 · 地点 · N 前活跃"）。**非本机**设备右侧有红色注销按钮 → 二次确认 → revoke
→ 刷新;本机不给注销钮（自注销会把 App 登出）。入口挂在 home 的按账户动作菜单
（`item('devices', …)` → `case 'devices'`）。

## 测试（`test/core/sessions_client_test.dart`，11 项）

enumerate：POST（非 GET，守住 GET/POST 陷阱）+ 带 token；解析 + 降序 + 标本机；
无符号 fixed64（-1 → `18446744073709551615`）；嵌套 last_seen 地点；空请求体；无
token 抛 `MissingAccessTokenException`。revoke：HMAC 参考向量（python 独立算）锁死
签名；请求编码（token_id/steamid/action=1/signature）+ POST；logout action=0；
无 token 守卫。

[roadmap]: 见 memory `ava-roadmap`。
