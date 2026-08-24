<h1 align="center">
  <img src="icon.png" height="64" width="64" />
  <br/>
  AVA
</h1>

<p align="center">
  <b>A</b>nother<b>V</b>apor<b>A</b>uth —— 用 <b>Flutter</b> 打造的现代化、轻量、跨平台 Steam 验证器。<br/>
  <sup>社区项目 —— 与 Steam / Valve 无任何关联。</sup>
</p>

<p align="center">
  单一代码库覆盖 <b>Windows · macOS · Linux · Android</b>（iOS 已规划）。
</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

---

> **安全提示：** 在电脑上做二次验证会削弱 2FA 的意义 —— 设备一旦被入侵，令牌也随之暴露。
> 能用 Steam 官方手机 App 就尽量用。务必备份你的 `maFiles` 和撤销码（revocation code）。
> 使用风险自负。

## 功能亮点

- **maFile 兼容** —— 读写旧版 `.maFile` 格式（PBKDF2/SHA1 + AES-256-CBC），老账户零成本迁移，随时可导出。还能导入整个 Steam Desktop Authenticator 的 `maFiles/` 文件夹——**包括加密的**（把 `manifest.json` 和 `.maFile` 一起选中；salt 与 IV 存在 manifest 里，孤立的加密 maFile 谁也解不开）——以及其他工具的变体（Steam++ / Watt Toolkit），包括没有 SteamID 的导出（作为「仅验证码」账户导入，验证码离线可用）。
- **Steam Guard 验证码** —— 每账户列表 + 实时倒计时环、点按复制；点名称在 用户名 / 昵称 / ID 间切换。
- **应用内批准登录** —— 在 AVA 内弹窗批准/拒绝 Steam 登录（显示设备 + 位置），与官方 App 一致，基于轮询、无需推送。
- **待办中心** —— 一个带页签的界面（账户右滑进入），集中处理所有等你决定的事：
  **确认**（交易 / 市场，批量接受/拒绝，原生 JSON、无内嵌 WebView）、**报价**
  （收到 / 发出 / 历史，可展开卡片显示双方物品，赠送 / 只给不收 / 暂挂警示条，
  接受后自动衔接对应的 mobileconf 确认）。
- **Steam 家庭组** —— 从账户菜单进入的只读家庭组页（成员、角色、名额、冷却），
  收到的邀请也在这里：先做加入前预检，再长按加入。*（实验性）*
- **长按确认** —— 所有不可逆的接受操作（交易报价、单条确认、加入家庭组）都用一次
  按住不放完成，带逐渐加速的震动；可在设置里关闭长按与震动。
- **库存与市场** —— 浏览账户的 Steam 库存（像 Steam 一样按游戏选择，相同物品堆叠），
  并把物品上架到社区市场：实时 Steam 费率、最高/最低成交走势、「你到手 ⇄ 买家支付」
  联动定价、批量上架、可选自动确认；「我的在售」页可撤销在售。长按账户即可进入。
- **自动刷新登录** —— access token 按需用 refresh_token 刷新；refresh_token 失效时可用保存的密码 + 账户自身 TOTP 无界面全量重登。
- **登录方式** —— 密码 + **扫码**、会话刷新、添加验证器、扫描他人二维码批准其登录。
- **应用锁** —— 强制 6 位 PIN 把关一个存于设备**硬件 Keystore** 的随机 256 位密钥，由它加密本地存储（AES-256-GCM）；支持指纹 / 设备密码解锁，输满 PIN 即自动登录。
- **加密同步**（可选）—— 把账户放到你自己掌控的 WebDAV 服务器上（Nextcloud、群晖，随便哪个）。所有内容在离开设备之前就已加密——服务器存到的是密文，永远看不到口令。冲突按账户而非按文件解决，所以两台设备各改各的账户时都不会丢。不配置就不启用。
- **动态头像** —— 拉取每个账户的 Steam 头像与头像框并播放（GIF 原生;APNG 自行解析并逐帧合成,正确处理每帧的偏移 / 混合 / dispose,带偏移的帧不再闪烁）。
- **外观与皮肤** —— 朴素的**浅色 / 深色 / 跟随系统**外观,以及独立的**皮肤**层(无 / 霓虹赛博朋克 / 像素复古),每套皮肤都是数据驱动的特效包,各有专属氛围与下拉刷新。
- **设备管理** —— 查看登录了某账户的所有设备与浏览器会话(平台、大致地点、
  最近活跃时间),可远程注销其中任意一台;本机会被标记且不能自注销。
- **兑换 Steam 密钥** —— 从账户菜单把产品密钥激活到该账户,Steam 的拒绝理由
  会写成人话(输错、已拥有、已被使用、地区不符、需要本体游戏、被限流)。
  激活不可撤销,因此提交前必定二次确认,失败也绝不自动重试。
- **首次启动手势教程**(触屏设备;桌面端改为账户行右键菜单)。
- **多语言**（English、简体中文、繁體中文、Deutsch、Français、Español、Русский）。
- **应用内调试日志**（设置 → 调试日志）—— 可复制的 Steam 流程网络追踪，便于诊断。

## 目录结构

```
app/      Flutter 应用（详见 app/README.md）
docs/     设计文档（docs/specs/）
```

**`legacy`** 分支保留了启发本项目的那个 .NET WinForms 版 Steam Desktop
Authenticator —— 仅供参考存档，AVA 与它不共享任何代码。

## 构建

需要 Flutter SDK（3.44.x）。详见 `app/README.md`。

```sh
cd app
flutter pub get --enforce-lockfile
flutter test                       # 728 项测试
flutter run -d linux               # 或 windows / macos

# Android 分 play / cn 两个 flavor，不带 --flavor 的构建会直接失败。
flutter build apk --release --split-per-abi --flavor cn --dart-define=AVA_CHANNEL=cn
```

每推送一个 `v*` 标签（或手动触发），GitHub Actions 会自动构建桌面版发布，
见 `.github/workflows/desktop-release.yml`：

- **Windows 安装包** —— scene 风格的单文件 `AVA-…-setup.exe`，由我们自研的
  Flutter 安装器（`installer/`）打包：无边框霓虹像素界面，装到用户目录免 UAC，
  自带开始菜单/桌面快捷方式与标准卸载项；卸载不会动账户数据。
- **Linux AppImage** —— 单文件 `AVA-…-linux-x86_64.AppImage`。

**便携版（Windows）**：由独立 workflow（`.github/workflows/windows-portable.yml`）
打包为**单文件** `AVA-…-portable.exe`（NSIS，`tool/portable.nsi`），免安装、放哪都能跑；
账户数据与安装版一样写入用户数据目录。

## macOS（Apple Silicon）

自 v1.2.0 起，每个 tag 版本的 [Releases](https://github.com/freefrank/AnotherVaporAuth/releases)
都提供 DMG——**仅 arm64**（M1 及之后的机型；不出 Intel 版）。打开 DMG，把
**AVA** 拖进 **Applications** 即可。

应用带 ad-hoc 签名但**未经 Apple 公证**（公证需要 $99/年的开发者账号；这是个
免费的社区项目），所以首次启动会被 Gatekeeper 拦下。放行方法：

1. **右键**（或按住 Control 点击）`AVA.app` → **打开** → **打开**。较新的
   macOS 上这个按钮可能要第二次尝试才出现，或者去
   **系统设置 → 隐私与安全性 → 「仍要打开」**。
2. 如果 macOS 提示应用「已损坏，无法打开」——那是未公证下载被打上的隔离标记，
   不是真的损坏。清掉它：

   ```sh
   xattr -dr com.apple.quarantine /Applications/AVA.app
   ```

两种都只需一次，之后正常启动。只对来源可信的软件做这件事——对 AVA 来说，
可信来源就是本仓库的 Releases 页：每个 DMG 都由 GitHub Actions 从打了 tag
的提交公开构建。

## 字体

所有字体均**打包进构建**（运行时不下载），在 `app/pubspec.yaml` 中声明；
详见 `app/assets/fonts/README.md`。

| 字体 | 主题 | 用途 | 来源 / 许可 |
|---|---|---|---|
| [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) | 霓虹 | 标题 | OFL 1.1 |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) | 霓虹 | 验证码 | OFL 1.1 |
| [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | 霓虹 | 中文（CJK）回退 | OFL 1.1 |
| [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font) | 像素 | 标题 + 验证码（拉丁 + 完整 CJK 含简/繁、假名、谚文） | OFL 1.1 |

像素主题使用**完整** Fusion Pixel 字体，实现完整 CJK 覆盖（含昵称中的生僻字）。
Noto Sans SC 子集化到 CJK 汉字区块（简体 + 繁体）。拉丁字体覆盖 ASCII。

## 致谢

AVA 是一个用 Flutter 从零写起的独立项目 —— 既非 fork 也非移植，灵感来自
老牌工具 **Steam Desktop Authenticator**（Jessecar96 及贡献者开发），并保持与其
`.maFile` 格式兼容，方便老用户迁移。Steam 认证协议参考：
[SteamAuth](https://github.com/geel9/SteamAuth)、
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session)。

## 隐私

你的 Steam 数据没有后端：账户、密钥与验证码全部留在设备上，所有 Steam 请求直连
Valve。另有三处服务会联网，写在这里而不是藏起来——Pro 权益校验、应用内反馈（仅在
你按下发送时）、以及 Play 版免费档的广告。详见[隐私政策](PRIVACY_ZH.md)
（[English](PRIVACY.md)）。

## 许可

见 [LICENSE](LICENSE)。打包字体各自保留其 OFL 1.1 许可。
