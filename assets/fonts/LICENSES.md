# Bundled font licenses

The fonts shipped in this directory are **not** covered by the project
`LICENSE` (PolyForm Noncommercial 1.0.0). Each is licensed independently
under the **SIL Open Font License, Version 1.1**, which permits bundling
and redistribution inside an application — including a commercial one —
provided the copyright notice and the license text travel with the font.
That is what this directory does.

| File | Family | Copyright | License text |
|---|---|---|---|
| `Goldman-Regular.ttf` | Goldman | 2018 The Goldman Project Authors | [`OFL-Goldman.txt`](OFL-Goldman.txt) |
| `Orbitron-Regular.ttf` | Orbitron | 2018 The Orbitron Project Authors — Reserved Font Name "Orbitron" | [`OFL-Orbitron.txt`](OFL-Orbitron.txt) |
| `ArchitectsDaughter-Regular.ttf` | Architects Daughter | 2010 Kimberly Geswein | [`OFL-ArchitectsDaughter.txt`](OFL-ArchitectsDaughter.txt) |
| `OpenDyslexic-Regular.otf` | OpenDyslexic | 2012–2019 Abbie Gonzalez — Reserved Font Name "OpenDyslexic" | [`OFL-OpenDyslexic.txt`](OFL-OpenDyslexic.txt) |

Every font here is **user-selectable** (Settings → Font, see
`core/theme/font_catalog.dart`). Nothing in the app hardcodes a family: the
launcher and the app drawer render through the Material 3 type scale of the
theme, so they follow whatever the user picked.

## Reserved Font Names

Orbitron and OpenDyslexic carry a Reserved Font Name. Under OFL §3 a
*modified* version may not be distributed under that name. Koru ships both
unmodified, so the restriction is satisfied by leaving them alone — if you
ever subset or re-hint either file, rename the family first.

## Why OpenDyslexic is `.otf` and the others are `.ttf`

Upstream ([antijingoist/opendyslexic](https://github.com/antijingoist/opendyslexic))
distributes OpenDyslexic only as OTF/WOFF — there is no official TTF. Both
Flutter and Android's `Typeface` load OTF, so the extension is carried
through verbatim rather than converted, which would create a modified
version and trip the Reserved Font Name clause above.

Two places hardcode the filename and must stay in sync with it:

- `pubspec.yaml` → `fonts:` section
- `android/app/src/main/kotlin/com/dev/koru/service/KoruFonts.kt` → `assetByFontId`
  (asserted by `KoruFontsTest`)
