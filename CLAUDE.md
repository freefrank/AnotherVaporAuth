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

## 硬性约束

- **绝不使用 `flutter install`**(它会先卸载应用,清空 maFiles/keystore 数据)。
  部署真机只用 `flutter run` 或 `adb -s <设备> install -r`。
- 用户折叠屏(如 192.168.1.83:36529)装有**真实 Steam 账户数据**:
  任何 adb 命令必须显式 `-s` 指定设备;绝不卸载旧包 `app.ava.authenticator`;
  绝不在真机确认页点击接受/拒绝。
- 签名密钥:`~/ava-upload.jks`(备份在 ownCloud 根),密码只存在
  `app/android/key.properties`(git 忽略)——不进仓库、不进对话。
- 模拟器测试用官方 AVD `ava_test`(emulator-5554),数据可随意处置;
  mock 账户 PIN 123456。
