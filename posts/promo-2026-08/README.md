# 推广批次 · 2026-08

1.0.1 上架 Play、商店条目补齐七种语言之后的一轮分发。这里放的是**投稿正文与
操作步骤**，不是已发布的帖子——发出去之后回来把状态改掉，别让这个表和现实脱节。

| 渠道 | 形态 | 状态 | 文件 |
|---|---|---|---|
| ava.dotslash.pro 换机指南（中英双语） | 站点长文 | **已上线** · [/guide/move-steam-authenticator/](https://ava.dotslash.pro/guide/move-steam-authenticator/) | 在 `dotslashpro` 仓库 |
| alternativeto.net | 登记条目 | 待执行（需账号） | [alternativeto.md](alternativeto.md) |
| HelloGitHub 月刊 | GitHub issue | **已提交 2026-08-09** · [#3523](https://github.com/521xueweihan/HelloGitHub/issues/3523) | [hellogithub.md](hellogithub.md) |
| 阮一峰《科技爱好者周刊》 | GitHub issue | **已提交 2026-08-09** · [#11089](https://github.com/ruanyf/weekly/issues/11089) | [ruanyf-weekly.md](ruanyf-weekly.md) |
| r/SteamBot | Reddit 帖 | 已写，未发 | [../en/reddit-2026-08/](../en/reddit-2026-08/) |
| r/droidappshowcase | Reddit 帖 | 已写，未发 | [../en/reddit-2026-08/](../en/reddit-2026-08/) |
| r/Steam | modmail | 已发，等回复 | [../en/reddit-2026-08/r-steam-modmail.md](../en/reddit-2026-08/r-steam-modmail.md) |
| 小黑盒 | 中文帖 | 已写 | [../zh/update-1.0.1/](../zh/update-1.0.1/) |

## 选渠道的标准

AVA 的钩子不是「又一个验证器」，是**多账号 + 从官方 App 迁移 + 能导出 maFile**。
选渠道只问一句：这里的人是不是正被这三件事之一卡着。不满足的地方人再多也不去。

## 发之前必须先修的三件事

这三条都不在上面的表里，但会直接吃掉上面每一条带来的流量：

1. ~~GitHub 仓库的 Homepage 指向爱发电~~ —— **已修（2026-08-17）**，现指向
   `https://ava.dotslash.pro`；爱发电移到了 `.github/FUNDING.yml` 的 Sponsor 按钮。
2. **仓库没有设置任何 Topics**。`steam` / `steam-guard` / `authenticator` / `2fa` /
   `totp` / `mafile` / `flutter` 这几个是 GitHub 站内搜索和 Explore 的主要入口，
   现在一个都没有，等于放弃了这条免费流量。
3. **README 顶部没有下载入口**。第一个 `##` 是 Highlights，安装信息埋在 Build
   （那是从源码构建，不是给用户的）。HelloGitHub 的审核标准把「快速开始」列为
   必须项，而对一个应用来说，快速开始就是 Play 链接和 Releases 链接。

## 有意没做的

- **Show HN**：只有一次机会，且它带来的是 star 和代码审计，不是装机量。等
  r/Steam 的回复落地、README 补完之后再考虑。
- **交易类社群**（backpack.tf、CS2 饰品 Discord、SteamRep）：转化率最高，
  但一个索要 maFile 的第三方工具长相和钓鱼工具完全一致，且这类社群基本禁自推。
  要进得先看规则、先有人认识你，不能空降。
- **F-Droid 主库**：`mobile_scanner` 打包的 ML Kit 是专有的，过不了收录政策。
  IzzyOnDroid 能进但会打 anti-feature 标。想彻底干净得换纯开源扫码实现，
  那是一笔真实的工作量，不是发个帖的事。

## 红线

- **不要用任何形式的奖励换评分或投票**。Play 政策禁止，alternativeto 明说
  会因此降权。
- 上面这批渠道的规则，只有 r/Steam、r/SteamSupport、r/opensource、
  r/androidapps 四个是逐条读过原文的。其余的发之前照样得先看一遍。
