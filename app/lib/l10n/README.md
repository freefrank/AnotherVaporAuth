# Localizations

`app_en.arb` is the template — it alone carries the `@key` metadata
(descriptions, placeholder types). Every other file holds **values only**;
duplicating the metadata makes it drift.

Adding a locale touches **three places that no compiler connects**:

1. `app_<locale>.arb` here
2. `kSelectableLocales` in `lib/src/app/providers.dart` (the settings picker)
3. `steamLanguageFor()` in `lib/src/app/app.dart` (Valve's own language slug)

Miss the third and that user reads AVA in their language while Steam-served
strings — item names, confirmation headlines — come back English.
`test/app/locales_test.dart` fails if the three drift apart.

Use the `l10n-translate` agent (`.claude/agents/l10n-translate.md`) rather
than translating by hand; it carries the per-locale traps.

## Repo-specific gotchas

- **`use-escaping` is off** (`l10n.yaml` never sets it). Apostrophes are
  ordinary characters — do **not** double them for French/Italian elision, or
  two apostrophes render on screen. The flip side: a literal `{` cannot be
  escaped at all. Turning the option on later would require doubling every
  apostrophe in every locale *including the English template*.
- **A locale may add ICU plural branches the template does not have** (Russian
  needs one/few/many where English has a bare placeholder). Verified working —
  gen-l10n emits `Intl.pluralLogic` — but only when the template declares that
  placeholder as `int`.
- **No bundled font contains U+202F** (narrow no-break space). French
  typographic spacing uses U+00A0, which 7 of the 8 fonts cover.
- **ChakraPetch (Neon skin display font) and NotoSansSC carry no Cyrillic.**
  Russian renders through system fallback under the Neon skin, so that skin
  loses its typographic identity for Russian users. Pixel is fine —
  FusionPixel covers Cyrillic. Fixing this means bundling another face.

## Open questions per locale

These need a native speaker with the relevant Steam client — they could not be
verified from here (Steam's localized help pages load their body via JS, and
`store.steampowered.com/twofactor/manage` is behind a login).

| Locale | Keys | Question |
|---|---|---|
| de, fr, es, ru | `addPresentStep1`, `addPresentStep2` | These quote the **verbatim menu path** for removing an authenticator. If the client's label differs (Entfernen/Löschen, Supprimer/Retirer, Eliminar/Quitar, Удалить/Убрать) the instruction points at a label that is not there. Only one menu item on that screen does this, so the user should still find it. |
| de, ru | revocation-code strings (`addAuthStepRevocation`, `exportWarnBody`, …) | "Widerrufscode" / «код отзыва». Both translators deliberately avoided the false friend (*Wiederherstellungscode* / *код восстановления* mean **recovery** code). The copy also shows the literal `R#####`, which disambiguates either way. |
| zh_Hant | `keyRedeem*`, `keyErr*` | 「媒體庫」 and 「產品代碼」 follow Valve's client wording as best known, but only 「市集」 was confirmed against a live Steam page. |
| all | `confTypeFeatureOptOut` | Opaque in the English source too; every translator flagged it. |

## Deliberate divergences from the English

- **`commonRefresh` vs `confirmationsRefresh`** are both "Refresh" in English.
  German uses the split deliberately: `commonRefresh` = "Neu laden" (it renders
  in a ~79 dp swipe tile that ellipsises) and `confirmationsRefresh` =
  "Aktualisieren" (tooltips, unconstrained). `market_screen.dart` uses
  `commonRefresh` for a tooltip, so German shows the short form there too.
- **passkey** is rendered as "encryption passphrase" in every locale
  (Verschlüsselungspasswort / phrase secrète / clave de cifrado / пароль
  шифрования / 通行碼) rather than the loanword. AVA's passkey is a local
  encryption passphrase; "passkey" now means WebAuthn in all five languages.
- **Hold-to-confirm pills** read "Action (hold)" rather than "Hold to action"
  in de/fr/ru — the pill shares a row with the decline button and the literal
  form overflows at 360 dp.
