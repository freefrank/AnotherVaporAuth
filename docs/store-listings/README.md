# Google Play 商店条目正本

`pro.dotslash.ava` 在 Play 上七种语言的商店条目文案。**这里是正本**——改文案
先改这里，再推到 Play，不要反过来（控制台改完这边就落后了，而且没人会发现）。

每个 `<locale>.txt` 一个语言，格式固定：

```
TITLE:
<一行>

SHORT:
<一行>

FULL:
<正文，到文件结束>
```

`FULL` 里的**行首缩进是有意义的**（英文与简中的 bullet 续行缩进 2 格），别用
编辑器的「去尾随空白/重排」功能扫这个目录。

## 字符上限（Play 的真实限制）

| 字段 | 上限 |
|---|---|
| `TITLE` | **30** |
| `SHORT` | 80 |
| `FULL` | 4000 |

**标题是 30 不是 50。** `play-store-mcp` 的 `validate_listing_text` 和
`update_listing` 的 docstring 都写 50，那是过时的——2026-08-08 实测它放行了一个
43 字符的标题，而 Play 侧只接受 30。以这里的表为准。

发布说明（release notes）是另一套东西，每语言上限 500 字符，正本在
`dist/release-notes-v<版本>.txt`（该目录 git 忽略）。见根 `CLAUDE.md`。

## 现状

| 语言 | 商店条目 | 发布说明 |
|---|---|---|
| en-US | ✅ | ✅ |
| zh-CN | ✅ | ✅ |
| zh-TW | ✅ | ✅ |
| de-DE | ✅ | ✅ |
| fr-FR | ✅ | ✅ |
| es-ES | ✅ | ✅ |
| ru-RU | ✅ | ✅ |

**发布说明的语言与商店条目的语言互相独立**——发布说明可以给任意 Play 支持的
语言，不要求该语言有商店条目。1.0.1 之前就是这个状态：七种语言的更新说明，
但只有 en-US / zh-CN 两份商店条目，德/法/西/俄/繁中用户看到母语的更新说明、
英文的商店页。2026-08-08 补齐了后五种。

**截图和特色图片没有按语言配**，全部回落到 en-US 那一套。新增语言不需要另出图。

## 推送

`play-store-mcp` 的 `update_listing`，一次一个语言；`language` 传一个尚不存在的
语言就是新建。三个字段都是可选的，只传要改的那个即可。

```
mcp__play-store__update_listing(
  package_name="pro.dotslash.ava",
  language="de-DE",
  title=..., short_description=..., full_description=...,
)
```

推完用 `list_all_listings` 回读确认，别只信返回的 `success: true`。

## 翻译

后五种语言 2026-08-08 由 `l10n-translate` subagent 从 **线上 en-US 条目**
翻译（不是从某份旧稿），术语对齐 `app/lib/l10n/app_<locale>.arb`，与应用内
用词保持一致。几个已知的软处：

- **「escrow」四种欧洲语言都没有定译**，用的是 ARB 里 `offerEscrow` 已有的
  描述性说法（de「zurückgehaltene Gegenstände」、fr「objets retenus par Steam」、
  es「objetos retenidos por Steam」、ru「задержка предметов」、zh-TW「Steam 保管期」）。
  如果 Steam 本地化客户端有官方词，换掉更准。
- **「Steam Family」同理**，Steam 是否把品牌名本地化未经核实。
- **fr-FR 标题冒号前是 U+00A0**（法语正字法），28/30，diff 里看不见这个字符。
  改法语标题时留意别把它算漏了。
- **zh-TW 的「皮膚」**跟随 `app_zh_Hant.arb`；台湾更常说「佈景主題」，但改这里
  会和应用内 UI 脱节，要改得两边一起改。

**「AVA Pro 可选 / 免费版在 Play 显示广告 / Steam 账户相关功能两者一致」那一段
是合规陈述，不是卖点**，七种语言里都必须在，不许弱化成营销话术。
