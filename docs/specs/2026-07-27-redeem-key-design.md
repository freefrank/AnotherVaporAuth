# 兑换 Steam 密钥（Redeem Key）设计

- 状态：**已实现并真机验证通过**（2026-07-29，随 v0.94.0 发布）。真实账户激活
  成功、收据里的产品名正常列出——`line_item_description` 那套字段名是对的，
  `packageName` 兼容分支从未命中，已删除。
- 来源：账户动作菜单扩展；同批次一并精简了触摸端长按菜单（见 §菜单精简）。
- 参考：Valve `store.steampowered.com/public/javascript/registerkey.js`、
  SteamKit `EPurchaseResultDetail`、ArchiSteamFarm `ArchiHandler.RedeemKey`、
  SteamDatabase/Protobufs `steammessages_store.steamclient.proto`、
  [steamapi.xpaw.me](https://steamapi.xpaw.me/IStoreService)。
- 相关：`app/lib/src/core/protocol/store_key_client.dart`、
  `app/lib/src/ui/redeem_key_screen.dart`、`app/test/core/store_key_client_test.dart`。

## 目标

在按账户的动作菜单里新增「兑换密钥」入口，把 Steam 商店「在 Steam 上激活产品」
那一步搬进 App：粘贴 / 输入密钥 → 二次确认 → 激活 → 列出到账的产品。

**激活不可逆**。一枚被消耗的密钥无法退回，也无法转到别的账户；因此本功能的每一
处设计取舍都偏向「宁可少激活一次，不可多激活一次」。

## 为什么不用 protobuf（`IStoreService/RegisterCDKey`）

ArchiSteamFarm 兑换密钥走的是 `CStore_RegisterCDKey_Request`（SteamKit 的
unified message），响应结构化、用 access token 鉴权——比 web 端点干净得多。
**但 AVA 用不了**：

- ASF 是通过 **CM 长连接**发这条消息的。AVA 是纯 Web API 客户端，没有 CM 传输。
- 该方法**没有**发布到 `api.steampowered.com`——
  [steamapi.xpaw.me/IStoreService](https://steamapi.xpaw.me/IStoreService)
  （自动从 `GetSupportedAPIList` 生成）列出的 22 个方法全是 `GetAppList` /
  `GetDiscoveryQueue` 这类查询，没有 `RegisterCDKey`。`callProtobuf` 打过去只会
  404，且我们的 GET/POST 约定（const 方法 GET、非 const POST）在这里根本用不上。

所以商店页自己的 ajax 端点是**唯一可用路径**。若 AVA 将来长出 CM 传输，应改用
protobuf 那条：字段号见 `steam/steammessages_store.steamclient.proto`——请求
`activation_code=1` / `purchase_platform=2` / `is_request_from_client=3`，响应
`purchase_result_details=1` / `purchase_receipt_info=2`。

## 协议

请求形状取自 Valve 自己的 `registerkey.js`——激活页的前端代码，即该端点的权威
消费者：

```
POST https://store.steampowered.com/account/ajaxregisterkey/
Content-Type: application/x-www-form-urlencoded
Cookie: steamLoginSecure=<steamid>||<access_token>; sessionid=<sid>
Referer: https://store.steampowered.com/account/registerkey
X-Requested-With: XMLHttpRequest

product_key=XXXXX-XXXXX-XXXXX&sessionid=<sid>
```

- 宿主是 `store.steampowered.com`，不是 `steamcommunity.com`——两台主机各有各的
  端点，故新增 `SteamApiClient.storeBase` / `storePostJson`。状态码处理与
  community 版复用同一个 gate：商店对失效会话的回应是 302 跳登录页，gate 会把它
  转成 `CommunityAuthException`，调用方据此走重登录，而不是把登录页 HTML 当成
  「密钥被拒」。
- Cookie 集合 `storeCookies()` **刻意不带 `mobileClient`**：商店对该标记会返回
  精简版移动端布局，ajax 端点不在其中。community 版的 `mobileClient` 留给社区主机。
- `X-Requested-With` 必须是浏览器的 `XMLHttpRequest`，**不是** community 那套
  `com.valvesoftware.android.steam.community` 包名标记（初稿抄错了）：这是商店页
  自己的 ajax，安卓包名标记同样会触发精简移动端布局。
- **必须先 GET 激活页 `/account/registerkey` 再 POST**（2026-07-28 实测）。商店在
  首次接触时会 `Set-Cookie` 下发 `steamCountry` + `browserid`，然后 **302 回同一个
  URL** 让你带着它们重来——即便 `steamLoginSecure` 完全有效。浏览器有 cookie jar
  会自动吸收重试，我们没有，于是第一发 POST 就卡死在这一跳（日志形如
  `HTTP 302 → .../ajaxregisterkey/`，跳向它自己）。`storeBootstrap()` 负责这一步：
  GET、跟随重定向（只在 Steam 源内）、吸收全部 Set-Cookie。GET 可安全重复，不消耗
  任何东西。
- **`sessionid` 优先用 Steam 下发的那个。** 初稿写「商店只校验 cookie 与表单字段
  一致，每次现生成即可」——**那是社区主机的行为，我未经验证就套到了商店主机上**。
  商店更严：自造的 id 它可能根本不认。现在 bootstrap 拿到什么就用什么，拿不到才现生成。
- 未鉴权的请求会被 302 到 `/login/?redir=...`（匿名实测），这条路径 `_isLoginRedirect`
  认得，会转成 `CommunityAuthException` 走重登录。**跳向自身**则是另一回事——是缺
  cookie，不是会话失效，两者必须分开看。

### 成功响应

```json
{
  "success": 1,
  "purchase_result_details": 0,
  "purchase_receipt_info": {
    "purchasestatus": 1, "resultdetail": 0,
    "line_items": [{"packageid": 12345, "line_item_description": "Portal 2"}]
  }
}
```

### `success == 1` 就是成功判据（照抄 Valve 自己的分支）

`registerkey.js` 的逻辑是：`success == 1` → 渲染收据；否则才去看
`purchase_result_details` 选错误文案。`KeyRedeemResult.parse` 与之一致。

**本设计初稿曾要求 `success == 1` 且 detail 为 0，那是错的。** 依据只是「实测
报告称部分拒绝也回 success:1」这个未经核实的说法，而比 Steam 自己的客户端更严
只会制造假阴性——把真的激活成功报成失败，用户会拿一枚已经属于自己的密钥再撞
一次限流。这也不是 `CLAUDE.md` 里 protobuf `optional bool success` 那条陷阱：
那个字段在线路上缺省即假，而这里是商店前端自己信任的显式 int。

空 body（共享 JSON 解码器对无体 200 返回 `{}`）没有 `success`，自然落到失败分支
——这是对的：没有收据可展示，谎报成功是更坏的错误。

### 字段名有两套，两套都读

### 字段名：产品名已定，结果码仍两套都读

**产品名 = `line_item_description`**（2026-07-29 真机确认：成功回执里产品名
正常列出）。这与 protobuf 字段 3 和 `registerkey.js` 实际读取的字段一致，两个
独立来源都对上了；只来自第三方抓包的 `packageName` 兼容分支从未命中，已删除。

结果码仍两套都读——真机只跑通了成功路径（detail=0 走的是顶层
`purchase_result_details`），失败分支里收据自带的那份到底叫 `result_detail`
（protobuf 字段 4）还是 `resultdetail`（web 抓包）尚未触发过，保留兜底。

### `purchase_result_details` 结果码

只映射 Valve 自己有独立文案的那几个，其余一律落到 `unknown` 并把原始数字显示给
用户。猜错原因比说「Steam 拒绝了（代码 N）」更糟——用户会照着错误的建议行动。

| 码 | 含义 | 枚举 |
|---|---|---|
| 0 | 成功 | — |
| 9 | 本账户已拥有该产品（`AlreadyPurchased`） | `alreadyOwned` |
| 13 | 该国家 / 地区无法激活（`RestrictedCountry`） | `regionLocked` |
| 14 | 密钥无效（`BadActivationCode`） | `invalidKey` |
| 15 | 密钥已被使用过（`DuplicateActivationCode`） | `alreadyActivated` |
| 24 | 需要先拥有本体游戏（`DoesNotOwnRequiredApp`） | `needsBaseProduct` |
| 36 | 需先在 PS3 主机上游玩过（`MustLoginPS3AppForPurchase`） | `needsPs3Login` |
| 53 | 近期失败次数过多，限流约一小时（`RateLimited`） | `rateLimited` |
| 其他 | — | `unknown`（显示原始码） |

数字取自 SteamKit `SteamLanguage.cs` 的 `EPurchaseResultDetail`（0–83 全表），
选进来的这七个正是 `registerkey.js` 有独立文案的那批。`4`（Timeout）与 `50`
（CannotRedeemCodeFromClient）是真实枚举值，但 Valve 自己把它们并进了兜底文案，
我们照做——显示原始码而不编造建议。

## 安全与不可逆性

1. **二次确认**。输入后必须再点一次确认弹窗才发请求；弹窗写明「不可撤销、无法
   转到别的账户」并带上目标账户名。
2. **不自动重试**。`RedeemKeyScreen` 调用 `fetchWithAutoRefresh` 时显式传
   `retryOnAnyError: false`。默认值会在**任何**失败后重发一次——包括 Steam 可能
   已经处理过的超时，那会把一次性密钥消耗在第二次激活上。只有 auth 类异常才
   重试，那类请求在密钥被消耗前就已被网关挡下。
3. **无 access token 直接抛异常**，不发请求（`requireAccessToken`）：带空 token
   发出去只会白白撞一次限流计数。
4. **密钥不进日志**。`dlog` 只记 success / detail / 产品数量；密钥本身是一次性
   凭据。输入框关掉 autocorrect 与 suggestions，避免进输入法词库。
5. **不做客户端格式校验**。密钥版式不止一种（15 位三段、25 位五段、Valve 自己的
   无连字符促销码），自作聪明地重排连字符会破坏我们不认识的版式。`normalize()`
   只做「去空白 + 转大写」，格式由 Steam 裁定。

### 错误处理

- 剪贴板读取（`Clipboard.getData`）走平台通道，桌面无剪贴板属主、安卓被别的 App
  占用锁时都会抛——已 try/catch，只记 `dlog`，不弹横幅（按钮回调里的未捕获异步
  异常才是问题）。
- 网络失败（`DioException`）不直接 `toString()` 给用户：那是多行开发者文案。改用
  `keyRedeemNetworkError`，且**不承诺密钥未被消耗**——接收超时可能发生在 Steam
  已处理之后，文案是「再试之前先到该账户的库里确认」。
- 会话已死（`isAuthError`）→ 走 `sessionErrorBody` 的重登录分支，不当成密钥被拒。

## 菜单精简（同批次）

长按弹出的触摸菜单原本重复列出了滑动手势已有的入口——待办（右滑）、刷新 / 导出 /
删除（左滑）——七项挤在一起，把**只有这里才有入口**的动作（市场、家庭组、设备）
埋在了下面。现在触摸菜单只留：市场 / 家庭组 / 设备 / 兑换密钥。

**桌面右键菜单保持完整八项**（待办 / 市场 / 家庭组 / 设备 / 兑换 / 刷新 / 导出 /
删除）。鼠标端没有手势教程，右键菜单是那几项唯一可发现的入口；侧栏那个刷新按钮
是全局刷新头像，不是本账户的重新登录。

## 待验证

真机实弹（需要一枚真实、未使用的密钥；建议先用一枚**故意打错的**密钥验证失败
路径，避免消耗）：

1. ~~`store.steampowered.com` 是否接受移动端 access token 组成的
   `steamLoginSecure`~~ —— **2026-07-28 间接证实可用**：真机上带该 cookie 的请求
   被 302 回自身（缺 cookie），而**匿名**请求被 302 到 `/login/`。既然商店没把我们
   赶去登录，说明它认了这个 token。
2. ~~收据里产品名的拼法~~ —— **2026-07-29 已确认 `line_item_description`**，
   `packageName` 分支已删。失败分支里收据自带的结果码拼法仍未触发过。
3. 结果码 9 / 13 / 14 / 15 / 24 / 36 / 53 的实际取值。SteamKit 的枚举可信，但
   商店 web 层是否原样透传未验证；若有偏差，改 `KeyRedeemResult.errorFor` 并补
   上表。
4. 是否需要额外 cookie（如 `birthtime`）才能通过年龄门。
