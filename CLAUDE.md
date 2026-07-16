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
- 不带 `--flavor` 的 Android 构建会直接失败;`flutter test/analyze` 与桌面
  构建不受影响。cn 包绝不允许包含 ads/billing/GMS 依赖(发布前用
  `apkanalyzer` 验收)。

## 文档位置

- 设计文档（spec）在 `docs/specs/`，实施计划在 `docs/plans/`（原 `docs/superpowers/` 已并入）。

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
