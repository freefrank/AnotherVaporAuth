# 实施计划 — SDA Flutter 重写（目标 0.90）

依据 spec：`docs/superpowers/specs/2026-06-29-flutter-rewrite-design.md`

## 阶段 & 进度

- [ ] 0. 工具链 (Flutter SDK 安装) + 项目脚手架 + pubspec
- [ ] 1. 核心库 steam_core（纯 Dart）
  - [ ] crypto: PBKDF2(50k,SHA1)+AES-256-CBC（maFile 兼容）
  - [ ] SteamTotp（验证码 + 确认哈希）
  - [ ] 模型: SessionData / SteamGuardAccount / Confirmation / Manifest
  - [ ] 兼容性回归单测（真实 maFile 加解密 + TOTP 向量）
- [ ] 2. 服务层: AccountStore / StorageProvider / SessionManager / ConfirmationService
- [ ] 3. 协议层（联网）: SteamAuthSession（密码+扫码A）/ Confirmations API / AuthenticatorLinker / 扫码批准B
- [ ] 4. UI（Material3 骨架，风格后补）: 解锁 / 主屏 / 确认 / 登录 / 添加验证器 / 导入 / 设置
- [ ] 5. i18n: en + zh ARB
- [ ] 6. 平台脚手架 (android/windows/linux/macos) + 构建验证

## 关键约束
- maFile 完全兼容（逐字段 + 加密一致）
- 逻辑等价现版本
- 核心库零 Flutter 依赖、可单测
