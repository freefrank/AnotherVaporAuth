# docs/plans — 实施计划索引

计划文档描述"怎么做"；对应的设计文档（"做什么/为什么"）在 `../specs/`。
完成的计划移入 `archive/` 并在标题下加归档说明（发布版本、遗留事项去向），
不再回填复选框——以 CHANGELOG 与代码现状为准。

## 活跃

| 计划 | 说明 | 状态 |
|---|---|---|
| [2026-07-16-paywall-prerequisites.md](2026-07-16-paywall-prerequisites.md) | Paywall 上线前置事项操作指南（六件事状态表 + §7 按类激活） | 进行中：#1 订阅商品与 #2 Google SA/OAuth **均已落地（2026-07-30）**，只剩 Play 沙盒联调；§7 beta 码按类激活**代码就绪、待用户部署**——预检已跑通且无残留，D1 里 `activation_log` 表尚不存在，可直接执行 migration + deploy |
| [2026-07-30-google-oauth-checklist.md](2026-07-30-google-oauth-checklist.md) | Google Cloud SA + OAuth 的逐步解冻清单（prerequisites §2 展开） | **已完成（2026-07-30）**：凭据全部就位、`kGoogleServerClientId` 已回填并随 v0.99.0 出包。表格内留有已核实的 client_id 与两个 SHA-1 |
| [2026-08-09-sda-ecosystem-gaps.md](2026-08-09-sda-ecosystem-gaps.md) | SDA 系 / maFile 兼容项目扫描，逐条对照 AVA 现状后的待补功能 | **挂起，下个版本**：未动代码。P0 是导入 SDA **加密** maFile——**密码学早就有了**（`MaFileCrypto` 与 `FileEncryptor.cs` 逐字节兼容，RFC 6070 向量锁死），缺的只是导入流程：`import_helper.dart:31` 先 `jsonDecode` 而密文不是 JSON，且 salt/iv 只存在于源 `manifest.json`，所以必须改成目录导入。**§P0 含一处 2026-08-11 的自我更正** |

## 归档

| 计划 | 发布 |
|---|---|
| [archive/2026-06-29-flutter-rewrite-plan.md](archive/2026-06-29-flutter-rewrite-plan.md) | 奠基实现（0.90 / 0.99，原 `app/PLAN.md`） |
| [archive/2026-07-15-trade-offers-todo-center.md](archive/2026-07-15-trade-offers-todo-center.md) | v0.81.0 |
| [archive/2026-07-15-family-groups.md](archive/2026-07-15-family-groups.md) | v0.82.0 |
| [archive/2026-07-15-paywall-android.md](archive/2026-07-15-paywall-android.md) | v0.90.0（订阅购买链路挂起，见活跃表） |
