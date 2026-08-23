# CLAUDE.md — AVA (AnotherVaporAuth) 项目约定

## 快捷指令

- **c** = commit:按主题拆分提交;commit message 末尾带 Co-Authored-By 与
  Claude-Session trailer。
- **b** = bump:升版本号(`app/pubspec.yaml` 的 version)并补 CHANGELOG
  中英条目。**写条目前必须先过一遍
  `git log --oneline <上一次 version bump 的 commit>..HEAD`**,把每条 `fix(` /
  `feat(` 拿出来问一句「用户会不会察觉」——会,就得进 `Fixed`/`Added`,不管
  成因多内部。2026-07 有三轮审计约 65 项修复因「加固都是不可见的」这个未经
  核实的假设而一条没写,其中包括每次启动都要重登、挂单价格差 100 倍、Pro 掉
  回免费——全都是用户直接能撞上的。纯重构与真·不可见的加固不写。
- **da** = doc-audit:调 `doc-audit` subagent 审计文档与现实的偏差(见
  `.claude/agents/doc-audit.md`)。发版前(b 之前)跑一次;它只报告不改文案。
  机器能判定的那部分由 `tool/docs_lint.py` 在 CI 里挡,不必等人跑。
- **p** = push:push 前必须本地 CI 通过(`flutter analyze` 无问题 +
  `flutter test` 全绿)。
- **发布说明每语言上限 500 字符**,超了整个 commit 被 403 拒(报
  `notes in language en-US with length N, which is too long`),不是截断。
  2026-07-30 发 1.0.0 时 563 字被拒过一次,压到 489 才过。发布说明正本在
  `dist/release-notes-v<版本>.txt`——**该目录 git 忽略**,只靠 Syncthing 同步,
  所以这条上限记在这里而不是那边。计长度时把 `\n` 按 CRLF 算(每行 +1)留余量。
- **发布说明的语言与商店条目的语言是两套东西**:发布说明可以给任意 Play 支持
  的语言,**不要求该语言有商店条目**。两边现在都是 en-US / zh-CN / zh-TW /
  de-DE / fr-FR / es-ES / ru-RU 七种,商店条目正本在 `docs/store-listings/`
  ——改了线上要同步改它,否则下次照着正本推就把线上覆盖回去。
  **标题真实上限是 30 字符**(MCP 的 `validate_listing_text` 说 50,是错的)。
- **/play** = 发 Play:见 `.claude/commands/play.md`,上传走
  `tool/play_deploy.py`,**不走 MCP**(原因见「Play 发布」)。
- 可组合使用,如 **cbp**。

## 工作树

- **唯一工作树:`~/sync/Git/AnotherVaporAuth`**(主机 `claude`)。不再有 WSL
  原生盘正本,也不再有 Windows 侧 ownCloud 镜像——开发、`flutter analyze/test/build`
  全在这里做(冷启动 analyze ~57s / test 696 例 ~5min)。
- `~/sync` 是 ZFS 数据集(`stor/backup/freefrank/syncthing`)上的 **Syncthing
  folder**,同步守护进程在宿主机侧,本机看不到进程。跨机分发由它自动完成,
  **不需要手工 rsync**。
- `~/sync/.stignore` 顶部有两条**例外**(2026-07-26 加,必须排在被否定的规则
  之前——Syncthing 按顺序匹配,第一条命中即生效):`!pubspec.lock` 放行锁文件、
  `!/Git/AnotherVaporAuth/dist/**` + `!/Git/AnotherVaporAuth/dist` 放行发布物。
  其余构建产物(`build/`、`node_modules/`)仍不同步。改这两条前先读下面这条。
- **`flutter pub get` 一律带 `--enforce-lockfile`**。lock 缺失或与 pubspec
  不一致时它会报错,而裸 `pub get` 会**静默重新解析并升级依赖**。2026-07-26
  就这么翻过车:新机器上 lock 因 `.stignore` 没落地,裸 `pub get` 把传递依赖
  `jni` 升到 1.0.1,其 `android/build.gradle` 调用了本项目没有的 `kotlin()`,
  `bundlePlayRelease` 直接失败——而 `analyze`/`test` **全绿**,因为两者都不
  走 Android Gradle。
- **依赖升级必须单开批次,验证矩阵含"出包"**:`analyze` + `test` 只覆盖 Dart
  层;插件问题只在 Gradle 构建和真机运行时现形(`flutter_secure_storage`、
  `google_mobile_ads` 尤甚)。少了出包这一步就不算验证过。

## Play 发布(上传不走 MCP)

- **上传一律用 `tool/play_deploy.py`**(PEP 723 脚本,`uv run` 自动装依赖,
  不污染系统 python;凭据取 `secrets/anothervaporauth-edaab169cb99.json`):

  ```sh
  ./tool/play_deploy.py status            # 各轨道当前版本
  ./tool/play_deploy.py deploy 1.2.1      # 演练:体检 + 打印线上状态,不上传
  ./tool/play_deploy.py deploy 1.2.1 --apply
  ```

  演练是默认行为,`--apply` 才真传。它会拦住三类事故:pubspec 与要发的版本
  不一致、**AAB 里的 versionCode 与 pubspec 对不上**(说明拿的是旧包)、
  发布说明某语言超 500 字符。

- **`mcp__play-store__deploy_app` / `batch_deploy` / `deploy_app_multilang`
  已弃用,不要再调。** 它的 `MediaFileUpload(..., resumable=True)` 不带
  `chunksize`,默认 100 MB,于是 85 MB 的 AAB 压进**单个** HTTP 请求;而
  `build()` 没传自定义 http,走 googleapiclient 的
  `DEFAULT_HTTP_TIMEOUT_SEC = 60`,`client.py` 里 `socket` 出现 0 次。
  传输本身只要 ~9 秒(实测上行 9.4 MB/s),卡住的是**传完之后 Google 处理
  bundle 的等待**,过 60 秒即断——包越大越必然失败:1.0.1 一次就过、
  1.2.0(85 MB)三次才中、1.2.1 四次全挂。`play_deploy.py` 两处都修了
  (8 MB 分片 + `socket.setdefaulttimeout(600)`,后者是 `build_http()` 自己
  的 docstring 指明的唯一覆盖途径)。
  **MCP 的只读工具照用**:`get_releases`、`get_reviews`、`get_listing`、
  `get_vitals_*`、`get_subscription_status`。
- **托管发布的「提交审核」没有 API。** `edits.commit` 只是把改动排进队列;
  最后一步必须人工去 Play Console 的发布概览点,点一次会把所有排队的版本
  一起提交。2026-08-16 就是因为没人点,1.2.0 一直停在概览页没上线。

## 发布分发(R2 + 站点 + 版本端点)

出包只是发布的一半;这三步漏掉任何一步都**不会报错**,只会让用户拿到旧版或
死链——`site.ts` 停在 v0.80.1 九个版本、「直发 apk」按钮指着不存在的产物,
都是这么来的(2026-08-18 又发现它停在 v1.2.0,漏掉了 1.2.1 与 1.2.2)。顺序执行:

0. **wrangler 报 7403 `not authorized to access this service` 时,先重跑一次。**
   它的 OAuth token **只有 1 小时寿命**,过期后远程调用不是报「未登录」,
   而是报这个长得像权限问题的 7403。随便跑一条 wrangler 命令
   （`whoami` 最快）就会用 refresh token 换新的,然后原命令直接就通了。
   **不要因此去 `wrangler login`,也不要去翻 account id**——2026-08-23 我
   两样都试了,真正起作用的只是那次 whoami 顺手刷新了 token。
   （两个 worker 的配置里确实写了 `account_id`,那是显式化,不是这个问题的解药;
   实测删掉它照样能跑。）
1. **`python3 tool/publish_r2.py --apply`**:把 `dist/AVA-v<版本>-*` 传到 R2
   (`dl.dotslash.pro`,cn APK 必需,桌面产物有则捎带),**逐个回读比对
   SHA-256**,再按桶里的 `r2-manifest.json` 删上一版的对象并写新清单。
   不带 `--apply` 是 dry-run。`version_dev.json`(dev 构建指向的 staging
   版本表)在 `KEEP_ALWAYS` 里,清理永不碰它。桌面产物先用
   `gh release download v<版本> -D dist/` 拉进 `dist/`。
2. **dotslashpro 仓库**:`ava/src/data/site.ts` 的 `TAG`/`VERSION` 改成新版,
   提交推送(Pages 自动部署),然后 `curl -sI` 实测下载链接——**看 content-type
   是不是真文件,别只看 200**(Pages 对未知路径回落 index.html 也是 200)。
3. **版本端点**:`infra/entitlement-worker/src/version.ts` 的表改成实际已
   发布的版本,`wrangler deploy`,然后 curl `api.ava.dotslash.pro/v1/version`
   核对。表过期不报错,只是所有客户端安静地查不到新版。

发 Play/GitHub 的部分照旧(`b`/`p`/tag、`/play`);此节只管分发面。

## 构建渠道(Android 已拆 flavor)

- Android 有两个 flavor:`play` / `cn`(同包名 `pro.dotslash.ava`)。Android
  构建/运行必须同时给 `--flavor` 与 `--dart-define=AVA_CHANNEL=`(两者一致,
  define 缺省回落 cn):
  - 日常开发/模拟器:`flutter run --flavor cn --dart-define=AVA_CHANNEL=cn`
  - 发布 play:`flutter build appbundle --flavor play
    --dart-define=AVA_CHANNEL=play` → `dist/AVA-v<版本>-play.aab`
  - 发布 cn:`flutter build apk --flavor cn --dart-define=AVA_CHANNEL=cn`
    → `dist/AVA-v<版本>-cn.apk`
  - **真机 dev 包**(与 Play 版并存的 `.dev` 副本,调试用):`flutter build apk
    --debug --flavor cn --dart-define=AVA_CHANNEL=cn --dart-define=AVA_DEV_PRO=true`
    → `dist/AVA-dev-v<版本>-cn.apk`。`AVA_DEV_PRO=true` 让 debug 构建默认解锁 Pro
    (预览付费皮肤);该 define 双重防呆(release/测试都不传 + `kDebugMode` 编译期
    为假),绝不会漏进发布版或干扰门控测试。
- 不带 `--flavor` 的 Android 构建会直接失败;`flutter test/analyze` 与桌面
  构建不受影响。
- **cn 包绝不允许包含 ads / billing 依赖**;**GMS 类是允许的**(2026-07-27
  确认:国行机型普遍集成 GMS)。原条文写的是「ads/billing/GMS 一律不许」,
  但 cn 包里那 700 多个 `com.google.android.gms.*` 里 93% 来自 `mobile_scanner`
  打包的 ML Kit 条码识别(`mlkit_vision_barcode_bundled`,扫 Steam 登录二维码
  用,本地识别),自 0.92 及更早就在,不是回归。要挡的是变现组件,不是 GMS 本身。
- **验收必须用 `apkanalyzer dex packages`,不能扫 zip 条目名**:release APK 的
  类全在 `classes*.dex` 里,按条目名 grep `com/google/android/gms` 恒为 0——
  那不是「干净」,那是这个检查从原理上就看不见类。2026-07-27 就这么误报过一次。
- **但 dex 检查在 release 上同样会假阴性:R8 会重写包路径。** 2026-07-30 实测
  cnRelease 的 `mapping.txt` 里 4218 个类被重命名、只有 382 个恒等映射,
  `com.google.android.gms.auth.api.signin.internal.Storage` 变成了 `d3.a`。
  当天按 `com/google/android/ump` 搜 AAB 的 dex 报「缺失」,而 `proguard.map`
  里 `UserMessagingPlatform.loadAndShowConsentFormIfRequired` 明明在——**两次
  误判,同一个原理:检查手段看不见目标 ≠ 目标不存在。**
  **权威依据是 `app/build/app/outputs/mapping/<变体>/mapping.txt`**(左侧是
  混淆前的原始类名,不受 R8 影响),AAB 里则是
  `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`:

  ```sh
  # cn 渠道门禁:必须为 0
  grep -cE "^com\.google\.android\.gms\.ads|^com\.android\.billingclient|^com\.google\.android\.ump" \
    app/build/app/outputs/mapping/cnRelease/mapping.txt
  ```

  dex 扫描仍可作为**辅助**(未被 keep 的类看不到),但不能单独作为通过条件。

  ```sh
  AK=~/Android/Sdk/cmdline-tools/latest/bin/apkanalyzer
  $AK dex packages --defined-only dist/<包>.apk | awk '$1=="P"' \
    | grep -Ei "\.ads|admob|billing|com\.android\.vending"   # 必须为空
  $AK manifest print dist/<包>.apk | grep -E "versionName|versionCode|package="
  ~/Android/Sdk/build-tools/*/apksigner verify --print-certs -v dist/<包>.apk
  ```

## 文档位置

- 设计文档（spec）在 `docs/specs/`，实施计划在 `docs/plans/`（原 `docs/superpowers/` 已并入）。
- 完成的计划归档到 `docs/plans/archive/`（标题下加归档说明；索引见 `docs/plans/README.md`）。
  审计记录在 `docs/` 根（`*-audit-*.md`），结论型决策同步进对应 memory。

## 隐私政策（改一处不够，要改两处）

- **正本**：仓库根 `PRIVACY.md` / `PRIVACY_ZH.md`（当前生效日期 2026-07-16，
  12 节，含「AVA Pro 订阅」与「广告（仅 Play 版免费档）」）。
- **线上**：`https://ava.dotslash.pro/privacy/`，源文件是**另一个仓库**里的
  `~/sync/Git/dotslashpro/ava/public/privacy/index.html`——**手工维护的静态页，
  没有生成脚本**。改了 `PRIVACY.md` 必须同步改它，否则 Play 商店条目指向的
  政策会和应用实际行为脱节。
- 2026-07-30 删掉了 `docs/privacy.html`：它停在 07-02、只有 10 节、缺的正是
  订阅与广告两节，而且**根本不是线上那份**。留着只会让人以为改它就能更新线上。
- README 里那段隐私概述也要跟着核，别让它和 `PRIVACY.md` 说的不是一回事。

## 密钥与 .env

- 本地密钥放仓库根 `.env`（git 忽略，权限 600），模板见 `.env.example`。
  与 `app/android/key.properties` 一样：**不进 git**，靠 Syncthing 跨机同步
  （`.stignore` 不挡它们）。
- 目前只有 `SMTP_PASS`（`hi@dotslash.pro`，用于发内测码）。
- **取密码用 `.env`**：`set -a; . ./.env; set +a`。不打印明文、不写进对话。
- **别去 grep `~/sync/Deployr/mailserver/CREDENTIALS.md`**。它是密码的正本
  （那里改了密码 `.env` 要跟着改），但格式是 markdown 表格
  `| Account | Email | Login | Password | Role |`——一行四个反引号字段，
  顺手 grep 第一个拿到的是 Email，2026-08-23 就这么 535 失败过一次。
- **发信失败先查证书，别先怀疑密码**。发内测码（`send_beta_codes.py`）与应用内
  反馈（`infra/feedback-worker`）都经 `mx.deployr.ca:587` + STARTTLS。2026-07-29
  该主机的 Let's Encrypt 证书到期未续，严格校验的客户端（Cloudflare Workers）
  握手直接失败，worker 回 502 `send failed`——**根本走不到 AUTH**，与密码无关。
  同一张证书还覆盖 `mail.deployr.ca` / `mail.dotslash.pro` / `mail.freshes.ca`
  的 587 与 993，故障面是整套邮件服务；证书与密码均以 `~/sync/Deployr/mailserver/`
  为正本。**`openssl s_client` 默认既不校验主机名、也不因过期中断**——它能跑通
  AUTH 并不证明证书有效，查有效期须加 `-verify_return_error -verify_hostname <host>`。

## 内测激活码（beta redeem）

- 码在 Cloudflare D1 `ava-entitlement`（id `6f949ca5-90b5-46d2-8db0-abce6f3eeb19`）
  的 `beta_testers(code, email, redeemed_by)`；worker 入口 `POST /v1/beta/redeem`。
- **一码四类端各一台**（**生产已是此行为**：`activation_log` 表在库里，
  worker 最后部署 2026-08-16）：与 Play 订阅同模型，android/windows/linux/macos
  各占一槽；重装同设备幂等，同类换机是带上限的替换（空槽首次认领不计数；
  KV 配置 `ACTIVATION_CAP`=5 次 / `ACTIVATION_WINDOW_DAYS`=90 天窗口，超限
  403 `code_activation_limit`），被踢设备下次 refresh 收 `device_revoked`。
  `redeemed_by` 只是记首个兑换者的审计字段，不再是闸门——**换机不需要人工清它**。
- 发码：`posts/zh/recruit/send_beta_codes.py`（`--test` 用假码预览 / `--one` /
  `--send [start]` 续发）。码**从 `testers-beta-codes.csv` 读，绝不现生成**——码已
  写进 D1，现生成会发出一批库里不存在的废码。
- `posts/` 默认进 git，但 `testers*.csv/txt`、`send_beta_*.py` 含真实邮箱（PII）
  与可用的 Pro 码，已在 `.gitignore` 挡掉；邮件模板只有占位符，可提交。
- 2026-07-16 已向 50 名内测成员各发一码（`AVA-BETA-` + 8 位 hex）。

## 硬性约束

- **绝不使用 `flutter install`**(它会先卸载应用,清空 maFiles/keystore 数据)。
  部署真机只用 `flutter run` 或 `adb -s <设备> install -r`。
- 用户折叠屏(192.168.1.83)装有**真实 Steam 账户数据**:
  无线调试端口每次重开都会轮换——**每次真机操作前问用户当前端口**,不要复用旧值;
  任何 adb 命令必须显式 `-s` 指定设备;**绝不卸载 `pro.dotslash.ava`**
  (2026-07-28 修正:此处原写 `app.ava.authenticator`,那个包名在本仓库
  查无出处——一条指向不存在的包的护栏等于没有护栏);
  绝不在真机确认页点击接受/拒绝(含报价长按接受、家庭组长按加入等一切写操作)。
- 签名密钥:构建用的工作副本是 `~/ava-upload.jks`(`key.properties` 的
  `storeFile` 写死这条绝对路径),**正本/备份是 `~/sync/ava-upload.jks`**
  ——`~/` 不同步,换机后工作副本会缺失,需从 `~/sync/` 拷回并 `chmod 600`,
  否则 release 签名直接失败(gradle 只检查 `key.properties` 存在,不检查
  keystore 文件存在)。entitlement 私钥 `~/sync/ava-entitlement-signing.pem` 同理。
  密码只存在 `app/android/key.properties`(git 忽略)——不进仓库、不进对话。
- **发布物必须 `flutter clean` 后构建**:2026-07-16 曾发生增量构建把过期的
  Dart AOT(libapp.so)打进"新"APK,导致连续多轮修复"装上没效果"——出
  dist 产物、以及排查"改了但行为没变"时,先 clean;真机验证要验**行为**,
  不能只看安装成功。
- **绝不在应用前台运行时改写自身组件状态**(setComponentEnabledSetting,
  含桌面图标 activity-alias 切换):ColorOS 会就地强停,表现为解锁页闪退
  循环。桌面图标跟随皮肤的功能因此于 0.90.1 整体下线,回归须找到运行中
  零组件写入的方案;新增会自动初始化的依赖(如 WorkManager)要检查其
  启动期组件写入行为。
- **新加滚动视图一律用 `context.rSafeInsets(...)`,不要用 `rInsets`**:
  targetSdk 是 36,Android 15 起强制边到边,Android 16 **忽略
  `windowOptOutEdgeToEdgeEnforcement`**——退不回去。Flutter 只在
  `BoxScrollView.padding` 为 **null** 时才自动补系统栏 inset,一旦传了显式
  padding(本项目每处都传)就静默失效,内容会钻到状态栏/手势条底下。
  `rSafeInsets` 会自适配:有 AppBar 时 Scaffold 已摘掉 top,它自动退化成只补
  底部;它同时会避开**屏幕圆角**——Flutter 的 MediaQuery **没有任何字段**描述圆角
  半径(padding/viewPadding/systemGestureInsets 都只管系统栏与挖孔),AVA 通过
  `ava/display` 通道读 Android 的 `WindowInsets.getRoundedCorner()`(API 31+,
  低版本与桌面回落 0),见 `lib/src/app/screen_corners.dart`。圆角与系统 inset
  取 **max 不是相加**——手势条那 24dp 本就落在圆角弧线扫过的高度里。
  Scaffold 自己定位的组件(FAB)用 `context.cornerOvershoot`,因为
  `FloatingActionButtonLocation` 已经抬过 `minViewPadding.bottom` 了。2026-07-28 一次性排查过全部滚动视图(其中一处是 `ListView.separated`,
  第一轮 grep 只匹配了 `ListView(`/`ListView.builder(` 而漏掉,由 doc-audit 抓出)。
- 模拟器测试用官方 AVD `ava_test`(emulator-5554),数据可随意处置;
  mock 账户 PIN 123456。**但本机(`claude`)当前没有模拟器**——`~/Android/Sdk/`
  没装 `emulator` 组件,`~/.android/avd/` 不存在(2026-07-26 单工作树迁移的
  残留)。要用得先 `sdkmanager` 装 emulator + system-image 再建 AVD;在此之前
  UI 改动只能靠真机 dev 包验证。
- **折叠屏上的 AVA 是 Play 版,本地构建永远装不上去**:Play App Signing 用
  Google 持有的密钥重签名,本地只有 upload key,`install -r` 必然
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`,唯一"解法"是卸载=清空真实 maFiles。
  真机调试改用并存的 dev 副本:debug buildType 已带 `applicationIdSuffix=".dev"`
  与 label "AVA dev"(release 包名不受影响)。两个图标必须一眼可辨——选错图标
  就是不可逆操作落到真实账户上。
- **Steam protobuf 的 `optional bool success` 不可信,别拿它当成功信号**:
  实测 `RemoveAuthenticatorViaChallengeStart` 成功时返回 eresult=OK + **0 字节
  空 body**(字段根本不存在),而 Continue 又确实填了 success=true。判断成功一律
  以 eresult(`callProtobuf` 已在非 OK 时抛异常)或**实际载荷是否存在**为准。
  字段编号要对照 SteamDatabase/Protobufs 核实,不要照抄第三方实现。
- 本机 `unzip` 不是标准实现,`-p`/`-l` 会把整个包解开到 cwd(曾把 aab 内容
  连同 `META-INF/` 签名文件吐进仓库根)。检查 apk/aab 用 `python3 -c
  "import zipfile..."`(只读),或先 cd 到临时目录。
