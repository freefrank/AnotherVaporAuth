# Changelog · 更新日志

All notable changes to **AVA (AnotherVaporAuth)**. Bilingual (English / 简体中文).
The format follows [Keep a Changelog](https://keepachangelog.com/); `v<MAJOR.MINOR>`
tags trigger automated releases.

本项目所有重要变更（中英双语）。格式参考 [Keep a Changelog](https://keepachangelog.com/)；
推送 `v<主.次>` 标签会触发自动发布。

## [v0.54] — 2026-06-30

Turned the remaining placeholder protocol code into real, on-device-validated
implementations. Login, session refresh and confirmations were verified against
a live Steam account.

把剩余的占位协议代码全部转为正式实现，并在真实 Steam 账户上完成真机验证 ——
登录、会话刷新、交易确认均已跑通。

### Added · 新增
- **In-app Debug log** (Settings → Debug log): a copyable, scrollable trace of
  every Steam request/response (method, EResult, size) for diagnostics.
  **应用内调试日志**（设置 → 调试日志）：可滚动、可复制的 Steam 请求/响应追踪
  （方法、EResult、大小），便于诊断。
- **Readable EResult names**: the full Steam `EResult` table (129 codes) — logs
  and errors now read e.g. `AccountLockedDown (73)` instead of a bare number.
  **可读的 EResult 名称**：完整 Steam `EResult` 表（129 个），日志与报错显示如
  `AccountLockedDown (73)`，不再是裸数字。
- **Mobile-confirmation login**: when an account allows in-app approval, AVA
  polls immediately so you can tap **Allow** in the Steam mobile app instead of
  typing a code; the manual code field stays as an alternative.
  **手机弹窗批准登录**：账户允许时立即轮询，可直接在 Steam App 点「允许」而无需
  输码；手动输码框作为备选保留。
- **CooldownButton**: submit buttons freeze for 1s after a press (counting down
  in 0.01s steps) to prevent accidental rapid re-submits.
  **冻结按钮**：提交后冻结 1 秒（每 0.01 秒步进倒数），防止手滑连点。

### Fixed · 修复
- **QR login** (`request_id` was read only on the credentials path) — scan-to
  -login no longer fails with `InvalidParam`.
  **扫码登录**：`request_id` 之前只在密码分支读取，导致扫码轮询报 `InvalidParam`，已修。
- **`steamid` is `fixed64`** in several messages — added `fixed64` to the
  protobuf codec and corrected AddAuthenticator, FinalizeAddAuthenticator,
  UpdateAuthSessionWithSteamGuardCode, GenerateAccessTokenForApp and the
  mobile-confirmation message.
  多处 **`steamid` 实为 `fixed64`** —— 给 protobuf 编解码器加 `fixed64`，并修正
  添加验证器、Finalize、令牌码提交、会话刷新及移动确认等消息。
- **QR-login steamid** is taken from the JWT `sub` claim (it isn't in begin/poll).
  **扫码登录 steamid** 改从 JWT 的 `sub` 提取（begin/poll 不返回）。
- **Guard code** tolerates `DuplicateRequest (29)` (already accepted) and
  proceeds to polling — this had blocked password login.
  **令牌码**容忍 `DuplicateRequest (29)`（已被接受）并转入轮询 —— 此前会卡住密码登录。
- **Confirmations auto-refresh**: on `needauth` AVA exchanges the refresh token
  for a fresh access token and retries `getlist` once — no re-login needed.
  **确认自动刷新**：遇 `needauth` 时用 refresh token 换新 access token 并重试一次
  `getlist`，无需重新登录。
- **AuthenticatorLinker** is now status-driven (no placeholder phone pre-check);
  `AccountLockedDown (73)` / `RateLimitExceeded (84)` map to clear messages.
  **添加验证器**改为 status 驱动（去掉占位的手机预检）；`AccountLockedDown (73)` /
  `RateLimitExceeded (84)` 映射为清晰提示。

### Changed · 变更
- Client identity aligned with the official Steam mobile app (okhttp User-Agent,
  API headers, `gaming_device_type`) to reduce "unknown device" anti-fraud flags.
  客户端标识对齐官方 Steam 手机 App（okhttp UA、API 头、`gaming_device_type`），
  降低合法登录被「陌生设备」风控误判。
- All user-facing strings localized (English + 简体/繁體); error/result messages
  and the Debug log UI were previously hardcoded English.
  所有用户可见文字本地化（英文 + 简体/繁體）；此前报错与调试日志界面为写死英文。

## [v0.53]
- Refined the remaining screens to the design language; added the in-app DebugLog
  infrastructure (network request/response logging).
  将其余界面精修至设计语言；加入应用内 DebugLog 基础设施（网络请求/响应日志）。

## [v0.52]
- Renamed the project to **AVA (AnotherVaporAuth)**; new app icon — Neon + Pixel
  variants, switchable in-app with the theme.
  项目更名为 **AVA (AnotherVaporAuth)**；新应用图标 —— 霓虹 + 像素双变体，随主题切换。

## [v0.51]
- Bundled full CJK fonts (simplified + traditional, incl. rare username glyphs);
  removed the legacy C# implementation (kept on the `legacy` branch); bilingual README.
  打包完整 CJK 字体（简体 + 繁体，含昵称生僻字）；移除旧版 C# 实现（保留在 `legacy` 分支）；双语 README。

## [v0.50]
- Updated all dependencies to latest stable; bundled fonts (no runtime download);
  switched to `file_selector`; CI Linux build uses Node 24.
  所有依赖更新至最新稳定版；字体打包（运行时不下载）；改用 `file_selector`；CI Linux 构建使用 Node 24。

## [v0.49]
- GitHub Actions: analyze/test on push, tag-driven releases (Android + Linux + Windows).
  GitHub Actions：推送即 analyze/test，标签触发发布（Android + Linux + Windows）。

## [0.1 – 0.48] — Flutter rewrite · Flutter 重写
- Complete rewrite from the legacy .NET WinForms app to **Flutter** (Windows /
  macOS / Linux / Android from one codebase). Byte-compatible `.maFile` crypto
  (PBKDF2 50k/SHA1 + AES-256-CBC), TOTP, confirmations (native JSON, batch),
  login (password + QR), add authenticator, two themes (Neon + Pixel), i18n.
  从旧版 .NET WinForms 完整重写为 **Flutter**（一套代码覆盖 Windows / macOS /
  Linux / Android）。字节级兼容的 `.maFile` 加密（PBKDF2 50k/SHA1 + AES-256-CBC）、
  TOTP、交易确认（原生 JSON、批量）、登录（密码 + 扫码）、添加验证器、双主题（霓虹 + 像素）、多语言。

[v0.54]: https://github.com/freefrank/SteamDesktopAuthenticator/releases/tag/v0.54
[v0.53]: https://github.com/freefrank/SteamDesktopAuthenticator/releases/tag/v0.53
[v0.52]: https://github.com/freefrank/SteamDesktopAuthenticator/releases/tag/v0.52
[v0.51]: https://github.com/freefrank/SteamDesktopAuthenticator/releases/tag/v0.51
[v0.50]: https://github.com/freefrank/SteamDesktopAuthenticator/releases/tag/v0.50
[v0.49]: https://github.com/freefrank/SteamDesktopAuthenticator/releases/tag/v0.49
