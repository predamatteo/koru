# Bundled font licenses

The fonts shipped in this directory are **not** covered by the project
`LICENSE` (PolyForm Noncommercial 1.0.0). Each is licensed independently
under the **SIL Open Font License, Version 1.1**, which permits bundling
and redistribution inside an application — including a commercial one —
provided the copyright notice and the license text travel with the font.
That is what this directory does.

| File | Family | Copyright | License text |
|---|---|---|---|
| `InstrumentSerif-Regular.ttf`, `InstrumentSerif-Italic.ttf` | Instrument Serif | 2022 The Instrument Serif Project Authors | [`OFL-InstrumentSerif.txt`](OFL-InstrumentSerif.txt) |
| `DMMono-Light.ttf`, `DMMono-Regular.ttf`, `DMMono-Medium.ttf` | DM Mono | 2020 The DM Mono Project Authors | [`OFL-DMMono.txt`](OFL-DMMono.txt) |
| `Goldman-Regular.ttf` | Goldman | 2018 The Goldman Project Authors | [`OFL-Goldman.txt`](OFL-Goldman.txt) |
| `Orbitron-Regular.ttf` | Orbitron | 2018 The Orbitron Project Authors — Reserved Font Name "Orbitron" | [`OFL-Orbitron.txt`](OFL-Orbitron.txt) |
| `ArchitectsDaughter-Regular.ttf` | Architects Daughter | 2010 Kimberly Geswein | [`OFL-ArchitectsDaughter.txt`](OFL-ArchitectsDaughter.txt) |
| `OpenDyslexic-Regular.otf` | OpenDyslexic | 2012–2019 Abbie Gonzalez — Reserved Font Name "OpenDyslexic" | [`OFL-OpenDyslexic.txt`](OFL-OpenDyslexic.txt) |

## Two groups, two different roles

Goldman, Orbitron, Architects Daughter and OpenDyslexic are **user-selectable**
(Settings → Font, see `core/theme/font_catalog.dart`).

Instrument Serif and DM Mono are not: they are the fixed typography of the
launcher ("Inchiostro e ore", see `core/theme/koru_type.dart`), the same pact
the clock had with Orbitron. They never appear in the font picker, so adding
them to `KoruFont` is not required — but they *are* in `pubspec.yaml`.

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
