# CLAUDE.md — AVA (AnotherVaporAuth) 项目约定

## 快捷指令

- **c** = commit:按主题拆分提交;commit message 末尾带 Co-Authored-By 与
  Claude-Session trailer。
- **b** = bump:升版本号(`app/pubspec.yaml` 的 version)并补 CHANGELOG
  中英条目。
- **p** = push:push 前必须本地 CI 通过(`flutter analyze` 无问题 +
  `flutter test` 全绿)。
- 可组合使用,如 **cbp**。
- **s / sync** = **已废弃**(2026-07-26)。旧流程是把 WSL 工作树 rsync 回
  `/mnt/c/.../ownCloud/Git/AnotherVaporAuth` 镜像;WSL 与该镜像现均已不存在,
  同步改由 Syncthing 自动完成(见「工作树」)。若将来恢复多机手工同步再重写本条。

## 工作树

- **唯一工作树:`~/sync/Git/AnotherVaporAuth`**(主机 `claude`)。不再有 WSL
  原生盘正本,也不再有 Windows 侧 ownCloud 镜像——开发、`flutter analyze/test/build`
  全在这里做(冷启动 analyze ~57s / test 545 例 ~50s)。
- `~/sync` 是 ZFS 数据集(`stor/backup/freefrank/syncthing`)上的 **Syncthing
  folder**,同步守护进程在宿主机侧,本机看不到进程。跨机分发由它自动完成,
  **不需要手工 rsync**。
- **`~/sync/.stignore` 会吃掉一批文件,别把它的表现误判成误删**:
  - `*.lock`(第 36 行)——`app/pubspec.lock`、`installer/pubspec.lock` **不会
    跨机同步**,在新机器上一律显示为 `D`(工作区删除)。lock 只能靠 **git**
    传播:改动要提交进仓库,新机器上用 `git restore` 取回,不要当误删修掉。
  - `build/`、`dist/`、`node_modules/` 等构建产物同样不同步——**`dist/` 的发布
    物只存在于生成它的那台机器上**,别指望在别处看到。

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
  构建不受影响。cn 包绝不允许包含 ads/billing/GMS 依赖(发布前用
  `apkanalyzer` 验收)。

## 文档位置

- 设计文档（spec）在 `docs/specs/`，实施计划在 `docs/plans/`（原 `docs/superpowers/` 已并入）。
- 完成的计划归档到 `docs/plans/archive/`（标题下加归档说明；索引见 `docs/plans/README.md`）。
  审计记录在 `docs/` 根（`*-audit-*.md`），结论型决策同步进对应 memory。

## 密钥与 .env

- 本地密钥放仓库根 `.env`（git 忽略，权限 600），模板见 `.env.example`。
  与 `app/android/key.properties` 一样：**不进 git**，靠 Syncthing 跨机同步
  （`.stignore` 不挡它们）。
- 目前只有 `SMTP_PASS`（`hi@dotslash.pro`，用于发内测码）。**正本是**
  `~/sync/Deployr/mailserver/CREDENTIALS.md` 的 `hi (dotSlash)` 行——那里改了
  密码，`.env` 要同步改。该文件自己也记着"搭建期密码应轮换"。
- 需要密码时从上述文件**管道取用**（`PASS=$(...)` → `SMTP_PASS="$PASS" cmd`），
  不打印明文、不写进对话。

## 内测激活码（beta redeem）

- 码在 Cloudflare D1 `ava-entitlement`（id `6f949ca5-90b5-46d2-8db0-abce6f3eeb19`）
  的 `beta_testers(code, email, redeemed_by)`；worker 入口 `POST /v1/beta/redeem`。
- **一码四类端各一台**（代码已改，**生产尚未部署**，见 prerequisites 文档 §7）：
  与 Play 订阅同模型，android/windows/linux/macos 各占一槽；重装同设备幂等，
  同类换机是带上限的替换（空槽首次认领不计数；KV 配置 `ACTIVATION_CAP`=5 次 / `ACTIVATION_WINDOW_DAYS`=90 天
  窗口，超限 403 `code_activation_limit`），被踢设备下次 refresh 收 `device_revoked`。
  `redeemed_by` 降级为只记首个兑换者的审计字段。部署前生产仍是旧行为：
  首个设备认领整码，其他设备一律 `code_redeemed`，换机需人工清 `redeemed_by`。
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
  任何 adb 命令必须显式 `-s` 指定设备;绝不卸载旧包 `app.ava.authenticator`;
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
- 模拟器测试用官方 AVD `ava_test`(emulator-5554),数据可随意处置;
  mock 账户 PIN 123456。
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
