# docs/plans — 实施计划索引

计划文档描述"怎么做"；对应的设计文档（"做什么/为什么"）在 `../specs/`。
完成的计划移入 `archive/` 并在标题下加归档说明（发布版本、遗留事项去向），
不再回填复选框——以 CHANGELOG 与代码现状为准。

## 活跃

| 计划 | 说明 | 状态 |
|---|---|---|
| [2026-07-16-paywall-prerequisites.md](2026-07-16-paywall-prerequisites.md) | Paywall 上线前置事项操作指南（六件事状态表 + §7 按类激活） | 进行中：只剩 Play 沙盒联调。#1 订阅商品、#2 Google SA/OAuth、§7 beta 码按类激活**均已落地**（`activation_log` 在库，worker 部署于 2026-08-16） |
| [2026-08-14-update-checker.md](2026-08-14-update-checker.md) | 更新检查（Android 跳商店/下载页）与桌面自更新，分两步 | **第一步已实现，在 `v1.3-autoupdate` 分支待合并**：只告知不安装，客户端 `update_check.dart` / `update_service.dart` + worker `/v1/version`（端点已上线，表停在 1.2.0，合并时一并更新）。第二步桌面自更新仍是设计。macOS 已恢复构建并随 v1.2.3 发布 DMG |
| [2026-08-09-sda-ecosystem-gaps.md](2026-08-09-sda-ecosystem-gaps.md) | SDA 系 / maFile 兼容项目扫描，逐条对照 AVA 现状后的待补功能 | **挂起，下个版本**：未动代码。P0 是导入 SDA **加密** maFile——**密码学早就有了**（`MaFileCrypto` 与 `FileEncryptor.cs` 逐字节兼容，RFC 6070 向量锁死），缺的只是导入流程：`import_helper.dart:31` 先 `jsonDecode` 而密文不是 JSON，且 salt/iv 只存在于源 `manifest.json`，所以必须改成目录导入。**§P0 含一处 2026-08-11 的自我更正** |

## 归档

| 计划 | 发布 |
|---|---|
| [archive/2026-06-29-flutter-rewrite-plan.md](archive/2026-06-29-flutter-rewrite-plan.md) | 奠基实现（0.90 / 0.99） |
| [2026-07-30-google-oauth-checklist.md](2026-07-30-google-oauth-checklist.md) | v0.99.0；凭据全部就位（文件仍在 `plans/` 根，留作 client_id / SHA-1 的查询表） |
| [archive/2026-07-15-trade-offers-todo-center.md](archive/2026-07-15-trade-offers-todo-center.md) | v0.81.0 |
| [archive/2026-07-15-family-groups.md](archive/2026-07-15-family-groups.md) | v0.82.0 |
| [archive/2026-07-15-paywall-android.md](archive/2026-07-15-paywall-android.md) | v0.90.0（订阅购买链路挂起，见活跃表） |
