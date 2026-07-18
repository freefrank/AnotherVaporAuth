# CLAUDE.md — AVA (AnotherVaporAuth) 项目约定

## 快捷指令

- **c** = commit:按主题拆分提交;commit message 末尾带 Co-Authored-By 与
  Claude-Session trailer。
- **b** = bump:升版本号(`app/pubspec.yaml` 的 version)并补 CHANGELOG
  中英条目。
- **p** = push:push 前必须本地 CI 通过(`flutter analyze` 无问题 +
  `flutter test` 全绿)。
- 可组合使用,如 **cbp**。
- **s / sync** = 全量同步回 Windows 侧镜像:
  - 目标:`/mnt/c/Users/freefrank/ownCloud/Git/AnotherVaporAuth/`
  - 用 rsync 同步整个工作树,**包括**未提交更改、未跟踪文件、被 gitignore 的
    工作资产(`store/`、`posts/`、`dist/`)以及**敏感文件**
    (如 `app/android/key.properties`)。
  - **排除**:`.git/`(镜像自己的 git 历史由 `git pull` 维护,不要覆盖)、
    `app/build/`、`app/.dart_tool/`、`node_modules/`、
    `app/linux/flutter/ephemeral/`。
  - 镜像克隆已设 `core.fileMode=false`(NTFS 权限位噪音);`dist/`、`posts/`、
    `store/` 在其 `.git/info/exclude` 里。
  - **WSL 工作树是唯一正本**:sync 用 `--delete`,镜像侧单独多出的文件会被
    删掉。要保留的文件(构建产物等)必须先放进 WSL 侧对应目录再 sync。
    构建产物统一先落 `dist/`(如 `dist/AVA-v<版本>.aab`)。
  - **s 的固定顺序**:①(若有新 push)镜像先 `git fetch origin &&
    git reset --hard origin/main` 对齐历史;② 再 rsync 全量覆盖——
    未提交更改、未跟踪文件、敏感文件全部以 WSL 工作树为准铺上去。
    顺序不能反:先 rsync 再 reset 会把未提交内容从跟踪文件里抹掉。
    不要用 pull(rsync 写入的未提交内容会让 pull 因"本地改动将被
    覆盖"而中止)。

## 工作树

- **编译正本是 WSL 原生盘 `~/SteamDesktopAuthenticator`**(目录沿用旧名,remote 已指
  向 AnotherVaporAuth)。开发、`flutter analyze/test/build` 都在这里做——比镜像快得多
  (analyze 约 9s vs 20s+)。
- 会话默认 cwd 常是 **Windows 侧镜像**
  `/mnt/c/Users/freefrank/ownCloud/Git/AnotherVaporAuth`(9P 挂载,慢);它只由 s
  同步流程更新,不在上面编译。
- 处理代码任务前先核对两棵树是否分歧
  (`git -C ~/SteamDesktopAuthenticator log --oneline -1` vs 镜像 HEAD),有分歧先对齐。

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
  与 `app/android/key.properties` 一样：**不进 git，但会被 `s` 的 rsync 带到镜像**。
- 目前只有 `SMTP_PASS`（`hi@dotslash.pro`，用于发内测码）。**正本是**
  `ownCloud/Deployr/mailserver/CREDENTIALS.md` 的 `hi (dotSlash)` 行——那里改了
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
- 签名密钥:`~/ava-upload.jks`(备份在 ownCloud 根),密码只存在
  `app/android/key.properties`(git 忽略)——不进仓库、不进对话。
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
