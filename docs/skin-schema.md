# AVA 皮肤包 Schema(v1)

皮肤的视觉特效以 JSON 描述,由内置引擎(`lib/src/skins/skin_engine.dart`)
渲染。内置的霓虹/像素皮肤就是两个标准包:`app/assets/skins/{neon,pixel}.json`
——它们既是实现,也是 schema 的参考样例。未来的可下载皮肤包沿用同一格式。

## 设计原则

- **数据驱动**:特效 = 引擎词汇表(层类型)+ JSON 参数。新皮肤在参数空间内
  自由组合,无需发版;全新的层类型才需要扩充引擎。
- **优雅退化**:引擎跳过不认识的层类型(逐层降级);`schema` 字段高于引擎
  支持版本时整包拒绝(避免只渲染一半的畸形效果)。
- **颜色双形态**:`#RRGGBB` / `#AARRGGBB` 字面量,或 `$token` 引用
  (`$bg $panel $panel2 $chrome $line $text $muted $accent $accent2 $good
  $bad $warn`),后者在绘制时对当前主题 tokens 求值——像素皮肤全部用引用,
  换 tokens 即换色。
- **解析失败静默**:坏包/坏字段回退到无特效或洋红占位色(#FF00FF,一眼可见
  的"spec 有 bug"信标),绝不崩溃。

## 顶层结构

```jsonc
{
  "schema": 1,              // 必填。引擎支持的最大版本见 SkinSpec.supportedSchema
  "id": "neon",             // 包标识
  "ambient": {              // 内容后面的背景层(全屏出血)
    "topFade": { "style": "gradient|steps", "color": "$bg" },  // 状态栏保护
    "layers": [ ... ]       // 按序绘制
  },
  "overlay": { "layers": [ ... ] },   // 内容上面的 HUD 层(安全区内)
  "scanline": { "gap": 3, "color": "#0D00F0FF", "animated": true },  // CRT 叠加,可省略
  "pull": {                 // 下拉刷新色染(引擎内置两种绘制风格,颜色是数据)
    "style": "neon|pixel",
    "colorA": "#18E0FF", "colorB": "#FF1B6B",   // 主色染对
    "lineA": "#00FFFF",  "lineB": "#FF2BD6"     // 扫线对(neon 风格用)
  },
  // ---- 预留(引擎暂不消费,供未来可下载包使用)----
  "tokens": { },            // 配色/圆角等设计 tokens(内置皮肤仍编译在 Dart 里)
  "fonts": [ ]              // 随包字体(运行时 FontLoader 注册)
}
```

## 层类型词汇表(v1)

### ambient 层

| type | 用途 | 主要参数(括号内默认值) |
|---|---|---|
| `glow_corner` | 角落呼吸辉光 | alignX/alignY(-1), color, alphaMin(.05)/alphaMax(.12), radius(1.1), invertPhase(false) |
| `grid` | 网格 | gap(34), color, alpha(.045), stroke(1), drift(true 随相位漂移), chunky(false=细线/true=像素矩形) |
| `glyph_rain` | 字符雨 | glyphs, cell(16), fontSize(13), fontFamily, headColor(#FFF)/headAlpha(.85), palette[](按列交替), alphaMin(.06)/alphaMax(.48), speedMin(60)/speedMax(230) px/s, lenMin(6)/lenMax(22), flicker(.18) |
| `sweep` | 柔和雷达扫线 | color, band(90), bandAlpha(.10), lineWidth(2), lineAlpha(.45), blur(8) |
| `band_step` | 硬步进亮带(8-bit) | color, px(4), speedFactor(1.3), alpha(.14), echoAlpha(.08) |
| `starfield` | 方块星野(像素步进) | color, color2, px(4), bands[{count, speed, size, alpha}] |
| `brackets` | 四角括号 | style("line"/"rect"), margin, arm, thickness, color, alpha, safeTop(false;true 时顶部让开状态栏) |

### overlay 层(绘制在内容之上、安全区内)

| type | 用途 | 主要参数 |
|---|---|---|
| `brackets` | 同上(细线 HUD 括号) | 同上(safeTop 无效,天然在安全区内) |
| `ticks` | 上下边缘刻度 | gap(16), longEvery(4), len(3)/lenLong(6), color, alpha(.25), inset(44) |
| `labels` | 角落小标签 | items[{text, anchor(tl/tr/bl/br), dx, dy}], color, fontSize(9), fontFamily, letterSpacing(1.5) |
| `rec_dot` | 闪烁 REC 圆点+标签 | text("REC"), color, anchor, dx, dy(闪烁周期引擎固定 1400ms) |

## 运行时行为

- 所有层共享一个 6 秒主相位循环;`glyph_rain` 另有逐列持久状态(位置/速度/
  字符),由引擎的单一 Ticker 驱动。
- 路由被全屏页覆盖时动画自动暂停;遵循系统"减少动态效果"(冻结相位)。
- 字形绘制走 TextPainter 缓存(按 字符|颜色|字体|字号 键控),逐帧只重绘。
- 加载:内置包经 `rootBundle` 异步读取(`skinSpecProvider`);皮肤=无 → spec
  为 null,所有引擎组件渲染为空。

## 版本策略

- 加"新参数"(旧引擎读默认值)→ 不升 schema。
- 加"新层类型"(旧引擎逐层跳过)→ 不升 schema。
- 改既有字段语义/结构 → schema+1,旧引擎整包拒绝。

## 未来:可下载包

规划的包格式:`<id>.avaskin`(zip:`skin.json` + 字体 + 图片),Ed25519
签名(与爱发电兑换码同一套密钥体系),经 `ava.dotslash.pro` 分发,Pro 解锁
后下载。tokens 段届时由 JSON 供给(明暗两套),字体经 FontLoader 运行时注册。
