# Bundled fonts

All fonts are bundled into the build (no runtime download). Declared in
`pubspec.yaml` under `flutter: fonts:` and wired up in `lib/src/app/theme.dart`.

| Family | Files | Theme | Coverage | License |
|---|---|---|---|---|
| ChakraPetch | Regular/Medium/SemiBold/Bold | Neon — display | Latin | OFL 1.1 |
| JetBrainsMono | Regular/Bold | Neon — code | Latin | OFL 1.1 |
| NotoSansSC | NotoSansSC.ttf | Neon — CJK fallback | Chinese (simplified + traditional) | OFL 1.1 |
| FusionPixel | FusionPixel.ttf | Pixel — display + code | Latin + full CJK (簡/繁) + kana + hangul | OFL 1.1 |

## Coverage

- **FusionPixel.ttf** — the **full** [fusion-pixel-font](https://github.com/TakWolf/fusion-pixel-font)
  (12px monospaced, zh_hans build, 36492 glyphs). Bundled whole, not subset, so
  rare characters (e.g. in usernames) and future locales (Japanese kana, Korean
  hangul, Cyrillic) all render in the pixel style.
- **NotoSansSC.ttf** — Noto Sans SC instanced to weight 400 and subset to the
  CJK ideograph blocks (CJK Unified Ideographs + Ext A + Compatibility) plus
  radicals, punctuation and Latin. Covers simplified + traditional Chinese; only
  non-Chinese scripts were dropped to save space.

To regenerate the Noto Sans SC subset (needs `fonttools`):

```sh
python3 -m fontTools.varLib.instancer "NotoSansSC[wght].ttf" wght=400 -o /tmp/notosc.ttf
RANGES="U+0020-007E,U+00A0-024F,U+2000-206F,U+2E80-2EFF,U+2F00-2FDF,U+3000-303F,U+31C0-31EF,U+3400-4DBF,U+4E00-9FFF,U+F900-FAFF,U+FE30-FE4F,U+FF00-FFEF,U+20000-2A6DF,U+2F800-2FA1F"
pyftsubset /tmp/notosc.ttf --unicodes="$RANGES" \
  --output-file=NotoSansSC.ttf --no-hinting --desubroutinize
```

Fusion Pixel is used as-is (the release `fusion-pixel-12px-monospaced-zh_hans.ttf`).
