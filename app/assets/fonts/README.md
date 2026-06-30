# Bundled fonts

All fonts are bundled into the build (no runtime download). Declared in
`pubspec.yaml` under `flutter: fonts:` and wired up in `lib/src/app/theme.dart`.

| Family | Files | Theme | Coverage | License |
|---|---|---|---|---|
| ChakraPetch | Regular/Medium/SemiBold/Bold | Neon — display | Latin | OFL 1.1 |
| JetBrainsMono | Regular/Bold | Neon — code | Latin | OFL 1.1 |
| NotoSansSC | NotoSansSC.ttf | Neon — CJK fallback | Chinese (subset) | OFL 1.1 |
| FusionPixel | FusionPixel.ttf | Pixel — display + code (Latin + CJK) | Latin + Chinese (subset) | OFL 1.1 |

## CJK subsetting

`FusionPixel.ttf` (from [fusion-pixel-font](https://github.com/TakWolf/fusion-pixel-font),
12px monospaced, zh_hans) and `NotoSansSC.ttf` (Noto Sans SC, instanced to
weight 400) are subset to the **GB2312** common-character set + ASCII + CJK
punctuation to keep the build small (≈1.4 MB and ≈2.3 MB respectively).

This covers everyday simplified Chinese (UI, common account names, trade text).
Rare or traditional-only characters outside GB2312 are not included.

To regenerate the subsets (needs `fonttools`):

```sh
# build the charset (GB2312 hanzi + ASCII + CJK punctuation) -> /tmp/charset.txt
python3 - <<'PY'
chars=set()
for hi in range(0xA1,0xF8):
    for lo in range(0xA1,0xFF):
        try: chars.add(bytes([hi,lo]).decode('gb2312'))
        except: pass
for c in range(0x20,0x7F): chars.add(chr(c))
for c in list(range(0x3000,0x3040))+list(range(0xFF00,0xFFF0)): chars.add(chr(c))
open('/tmp/charset.txt','w',encoding='utf-8').write(''.join(sorted(chars)))
PY

pyftsubset fusion-pixel-12px-monospaced-zh_hans.ttf \
  --text-file=/tmp/charset.txt --output-file=FusionPixel.ttf \
  --no-hinting --desubroutinize

python3 -m fontTools.varLib.instancer "NotoSansSC[wght].ttf" wght=400 -o /tmp/notosc.ttf
pyftsubset /tmp/notosc.ttf \
  --text-file=/tmp/charset.txt --output-file=NotoSansSC.ttf \
  --no-hinting --desubroutinize
```
