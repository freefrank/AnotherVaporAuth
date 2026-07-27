# docs/plans — 实施计划索引

计划文档描述"怎么做"；对应的设计文档（"做什么/为什么"）在 `../specs/`。
完成的计划移入 `archive/` 并在标题下加归档说明（发布版本、遗留事项去向），
不再回填复选框——以 CHANGELOG 与代码现状为准。

## 活跃

| 计划 | 说明 | 状态 |
|---|---|---|
| [2026-07-16-paywall-prerequisites.md](2026-07-16-paywall-prerequisites.md) | Paywall 上线前置事项操作指南（六件事状态表 + §7 按类激活） | 进行中：#1 建订阅商品待做（#6 内测码 2026-07-26 查库确认**已完成**）；#2 Google SA/OAuth **挂起**；§7 beta 码按类激活**代码就绪、待用户部署**——预检已跑通且无残留，D1 里 `activation_log` 表尚不存在，可直接执行 migration + deploy |

## 归档

| 计划 | 发布 |
|---|---|
| [archive/2026-06-29-flutter-rewrite-plan.md](archive/2026-06-29-flutter-rewrite-plan.md) | 奠基实现（0.90 / 0.99，原 `app/PLAN.md`） |
| [archive/2026-07-15-trade-offers-todo-center.md](archive/2026-07-15-trade-offers-todo-center.md) | v0.81.0 |
| [archive/2026-07-15-family-groups.md](archive/2026-07-15-family-groups.md) | v0.82.0 |
| [archive/2026-07-15-paywall-android.md](archive/2026-07-15-paywall-android.md) | v0.90.0（订阅购买链路挂起，见活跃表） |
