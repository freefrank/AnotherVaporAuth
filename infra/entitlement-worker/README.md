# ava-entitlement

AVA Pro 订阅权益后端(Cloudflare Worker + D1 + KV)。按渠道(Google Play 订阅 /
爱发电 / beta 码 / AdMob 激励视频 VIP)验证购买,签发 24 小时有效的
EdDSA(Ed25519)JWT;客户端(`app/lib/src/core/entitlement.dart`)用内嵌公钥
离线校验。**Token claims 与客户端严格同步,改动必须两边一起改。**

## 端点

| 端点 | 说明 |
| --- | --- |
| `POST /v1/token/refresh` `{token, device_id}` | 轮换 token。旧 token 可过期但签名必须有效。403:`revoked` / `device_revoked`(同类新设备已把名额顶掉)/ `entitlement_ended` / `invalid_token` |
| `POST /v1/play/verify` `{id_token, purchase_token, device_id, device_class}` | 验 Google id_token + Play 订阅,upsert 权益并占设备名额,签 token |
| `POST /v1/afdian/redeem` `{order_no, device_id, device_class}` | 通过爱发电开放平台核验订单;订单绑定他人 → 403 `order_bound` |
| `POST /v1/afdian/webhook` | 爱发电续订推送。推送无签名,靠回查 query-order 鉴别真伪;响应 `{ec:200}` |
| `POST /v1/beta/redeem` `{code, device_id, device_class}` | beta 码兑换,签终身 pro(pro=0);按设备类占名额(同 Play),同类换机为受限 REPLACE,超出激活上限 403 `code_activation_limit`(附 `activations` 名额表,只含类与时间戳);`redeemed_by` 仅留作首兑审计,不再作门禁 |
| `POST /v1/entitlement/status` `{token}` | 查询权益与各设备类名额:`{channel, tier, pro_until, activations:[{device_class, activated_at, this_device}]}`;验签名 + 当前名额持有者、不看过期(同 refresh);403:`invalid_token` / `entitlement_ended` / `revoked` / `device_revoked`(名额已被同类新设备顶掉) |
| `POST /v1/vip/claim` `{device_id, device_class}` | 领取 SSV 已建立的 VIP 权益(客户端看完广告后轮询);无有效 VIP → 404 `{error:'no_vip'}` |
| `GET /v1/admob/ssv?...` | AdMob 激励视频服务端回调(ECDSA 验签);`user_id` = 客户端 device_id;成功 200 空体 |

错误统一 `{error: string}`;签发成功统一 `{token: string}`。

设备名额:**每权益每设备类(android/windows/linux/macos)一个**,新设备激活即
REPLACE,旧设备下次 refresh 收 403 `device_revoked`。beta 码 / 爱发电这类
**可转述凭据**的换机受激活次数约束:每(权益, 设备类)在滑动窗口
(KV `ACTIVATION_WINDOW_DAYS`,默认 90 天)内至多 `ACTIVATION_CAP`(默认 5)
条 `activation_log`(只计**顶掉他机**的 REPLACE;空槽首次激活与同设备重装
不计),超出 403 `code_activation_limit`;Play/VIP 锚定账号,不设上限。
残余限制:device_id 按安装生成,worker 无法识别"同一台物理设备重装"——
窗口内重装超过上限的设备仍需人工清其 `activation_log`。

## 部署步骤(全部手动执行,勿在 CI 里自动跑)

```sh
npm install

# 1. 创建 D1 与 KV,把返回的 id 填进 wrangler.jsonc 的占位符
npx wrangler d1 create ava-entitlement
npx wrangler kv namespace create CONFIG

# 2. 执行 migration
npx wrangler d1 migrations apply ava-entitlement --remote

# 3. 生成 Ed25519 签名密钥对
openssl genpkey -algorithm ed25519 -out ava-entitlement-signing.pem
#   worker 私钥 secret(base64 PKCS#8):
openssl pkey -in ava-entitlement-signing.pem -outform DER | base64 -w0
#   客户端内嵌公钥(raw 32 字节,hex;SPKI DER 的最后 32 字节):
openssl pkey -in ava-entitlement-signing.pem -pubout -outform DER | tail -c 32 | xxd -p -c 64

# 4. 设置 secrets
npx wrangler secret put ENTITLEMENT_SIGNING_KEY   # 上面第一条命令的输出
npx wrangler secret put AFDIAN_USER_ID
npx wrangler secret put AFDIAN_TOKEN
npx wrangler secret put AFDIAN_PLAN_ID
npx wrangler secret put GOOGLE_SA_EMAIL
npx wrangler secret put GOOGLE_SA_KEY             # service account 私钥(PEM 原文即可)
npx wrangler secret put PLAY_PACKAGE_NAME         # pro.dotslash.ava
# 可选:npx wrangler secret put GOOGLE_CLIENT_ID  # 锁定 id_token 的 aud

# 5. 可选 KV 配置
npx wrangler kv key put --binding CONFIG VIP_DAYS 3   # 每次激励视频的 VIP 天数,默认 3
npx wrangler kv key put --binding CONFIG ACTIVATION_WINDOW_DAYS 90  # 换机计数窗口,默认 90
npx wrangler kv key put --binding CONFIG ACTIVATION_CAP 5           # 窗口内每设备类激活上限,默认 5

# 6. 部署(注意本账号 workers.dev 有故障,需配自定义域路由,见 wrangler.jsonc)
npm run deploy
```

Beta 码发放:直接往 D1 插行:

```sh
npx wrangler d1 execute ava-entitlement --remote \
  --command "INSERT INTO beta_testers (code, email) VALUES ('AVA-BETA-XXXX', 'tester@example.com')"
```

## 开发

```sh
npm test            # vitest,全部离线(外部调用注入假件)
npm run typecheck   # tsc --noEmit
```

结构:`src/logic.ts` 是纯业务逻辑,所有外部依赖(D1 Store、Google、爱发电、
AdMob、KV 配置、时钟)通过 `Deps` 注入;`src/index.ts` 负责组装生产依赖。
路由是原生 fetch handler + switch,无框架。

## 上线前待核验(TODO)

- **爱发电 API**:sign 算法(md5(token+params+ts+user_id 拼接))、query-order
  响应字段(`status==2`=已支付、`create_time`、`month`)需对照开放平台文档核验。
- **Play Developer API**:subscriptionsv2 响应(`subscriptionState` 取值、
  `lineItems[].expiryTime`)与订阅 acknowledge 要求(3 天不 ack 会自动退款,
  当前未调用 acknowledge)需对照官方文档核验。
- **id_token aud**:目前只在设置了 `GOOGLE_CLIENT_ID` 时校验 aud,上线前应
  配置该 secret 并强制。
- **月长**:爱发电按月订阅按 30 天/月折算(`MONTH_SECONDS`),如需自然月需改。
- **workerd Ed25519 JWK 导出**:公钥从私钥 `exportKey('jwk').x` 推导,Node 下
  已测试通过;部署后应在 workerd 上冒烟验证一次 refresh 往返。
- **wrangler.jsonc**:D1/KV id 为占位符;需配自定义域路由。
