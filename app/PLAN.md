# 实施计划 — SDA Flutter 重写（目标 0.90）

依据 spec：`docs/superpowers/specs/2026-06-29-flutter-rewrite-design.md`

## 阶段 & 进度

- [x] 0. 工具链 (Flutter 3.44.4 / Dart 3.12.2) + 项目脚手架 + pubspec
- [x] 1. 核心库 steam_core（纯 Dart）
  - [x] crypto: PBKDF2(50k,SHA1)+AES-256-CBC（maFile 兼容，RFC6070 锁定）
  - [x] SteamTotp（验证码 + 确认哈希，跨实现校验）
  - [x] 模型: SessionData / SteamGuardAccount / Confirmation / Manifest（无损往返）
  - [x] protobuf 线编解码器
- [x] 2. 服务层: StorageProvider / AccountStore / SteamApiClient / SteamTime / SessionManager
- [x] 3. 协议层（联网）: SteamAuthSession（密码+扫码A）/ Confirmations / AuthenticatorLinker / 扫码批准B
- [x] 4. UI（Material3 骨架）: 解锁 / 主屏 / 确认（批量）/ 登录 / 添加验证器 / 扫码批准 / 设置
- [x] 5. i18n: en + zh ARB（编译期生成）
- [x] 6. 验证: flutter analyze 零问题；34 测试通过；UI 冒烟渲染通过
- [x] 7. Linux 桌面二进制构建成功（debug + release）—— release bundle 仅 27MB
- [ ] Android APK 构建 —— 需 Android SDK/NDK（本机未装；`pacman -S android-sdk` 或 Android Studio 后 `flutter build apk`）

## 测试覆盖（34 项）
- PBKDF2 RFC6070 向量、AES-CBC 往返、TOTP/确认哈希跨实现向量
- protobuf 往返、模型无损 JSON、QrChallenge 解析
- AccountStore 端到端（加密/解锁/改密/导入/移除/排序）
- App 冒烟渲染

## 待真机联调（无法在无凭据/无网环境验证）
- Steam 新登录协议（密码/扫码A）、会话刷新
- mobileconf 确认（getlist/ajaxop/multiajaxop）
- 添加验证器（AddAuthenticator/Finalize/SMS）
- 扫码批准（方向B）签名细节
