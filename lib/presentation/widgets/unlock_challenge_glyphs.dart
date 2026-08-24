import 'package:flutter/material.dart';

import '../../domain/entities/unlock_challenge.dart';

/// Mappa id simbolico → icona Material per i glifi della sfida di sblocco.
///
/// La tabella vive qui e non in `domain/` perché `IconData` è Flutter e
/// `domain/` deve restarne pulito (vedi l'header di [UnlockChallenge]).
///
/// Regola nel scegliere le icone: **dentro una famiglia devono somigliarsi**
/// (stessa silhouette, cambia solo rotazione o riempimento) e **fra famiglie
/// no**. È l'unica cosa che rende i distrattori dei distrattori veri; sostituire
/// un'icona con una troppo diversa svuota silenziosamente la difficoltà.
///
/// Ci sono però due modi di somigliarsi che sono difetti, non difficoltà, e
/// nessuno dei due si vede rileggendo il codice — solo guardando il font:
///
/// 1. **Somigliarsi troppo.** `Icons.star_border` e `Icons.star_outline` sono
///    due `IconData` diverse con due codepoint diversi che disegnano lo
///    **stesso identico glifo**. Con una a bersaglio e l'altra a sosia il
///    puzzle non è difficile, è impossibile: due caselle indistinguibili e un
///    tocco sbagliato brucia il tentativo. Vale per ogni coppia di icone
///    "alias" del set Material — sono parecchie.
/// 2. **Somigliare al glifo mancante.** Un quadrato vuoto e basta
///    (`Icons.crop_square`, `Icons.check_box_outline_blank`, `Icons.crop_din`)
///    è indistinguibile dal `.notdef` che il font disegna quando un codepoint
///    non c'è. L'utente non vede un simbolo da ricordare, vede l'app rotta.
///    Da qui la famiglia `square` fatta di quadrati con qualcosa dentro.
///
/// La contromisura vera non è un test: è **guardare la griglia**. Le poche
/// regole meccaniche che *si possono* verificare — un'icona per ogni id,
/// nessun codepoint usato due volte, nessuno dei quadrati vuoti noti — stanno
/// in `test/presentation/unlock_challenge_glyphs_test.dart`.
const Map<String, IconData> kGlyphIcons = {
  // Frecce piene — differiscono solo per rotazione.
  'arrow_up': Icons.arrow_upward,
  'arrow_down': Icons.arrow_downward,
  'arrow_left': Icons.arrow_back,
  'arrow_right': Icons.arrow_forward,

  // Chevron — stessa rotazione delle frecce ma senza asta: sosia perfetti.
  'chevron_up': Icons.keyboard_arrow_up,
  'chevron_down': Icons.keyboard_arrow_down,
  'chevron_left': Icons.keyboard_arrow_left,
  'chevron_right': Icons.keyboard_arrow_right,

  // Stelle — pieno / vuoto / mezzo / contorno sottile.
  // NON usare `Icons.star_outline` per il contorno sottile: disegna lo stesso
  // glifo di `Icons.star_border`, quindi "vuoto" e "sottile" finirebbero
  // identici. `star_purple500` è il contorno davvero più fine (il nome viene
  // dal set Material, nel font è monocromatico come tutte le altre).
  'star_full': Icons.star,
  'star_empty': Icons.star_border,
  'star_half': Icons.star_half,
  'star_thin': Icons.star_purple500,

  // Cuori.
  'heart_full': Icons.favorite,
  'heart_empty': Icons.favorite_border,
  'heart_broken': Icons.heart_broken,

  // Cerchi concentrici.
  'circle_full': Icons.circle,
  'circle_empty': Icons.radio_button_unchecked,
  'circle_target': Icons.adjust,
  'circle_dot': Icons.radio_button_checked,

  // Quadrati — stessa sagoma, cambia solo il segno interno. Il contorno vuoto
  // e basta è vietato qui: vedi il punto 2 dell'intestazione.
  'square_full': Icons.square,
  'square_check': Icons.check_box,
  'square_dash': Icons.indeterminate_check_box,
  'square_cross': Icons.disabled_by_default,

  // Triangoli — contorno + le tre rotazioni piene.
  'triangle_empty': Icons.change_history,
  'triangle_right': Icons.play_arrow,
  'triangle_up': Icons.arrow_drop_up,
  'triangle_down': Icons.arrow_drop_down,

  // Lune.
  'moon_full': Icons.dark_mode,
  'moon_tilt': Icons.nightlight,
  'moon_bed': Icons.bedtime,
  'moon_thin': Icons.brightness_3,

  // Orologi e clessidre.
  'clock_face': Icons.schedule,
  'clock_timer': Icons.timer,
  'clock_sand_top': Icons.hourglass_top,
  'clock_sand_bottom': Icons.hourglass_bottom,

  // Foglie — la famiglia "di casa" di Koru.
  'leaf_eco': Icons.eco,
  'leaf_spa': Icons.spa,
  'leaf_flower': Icons.local_florist,
  'leaf_tree': Icons.park,

  // Fulmini.
  'bolt_plain': Icons.bolt,
  'bolt_flash': Icons.flash_on,
  'bolt_circle': Icons.offline_bolt,

  // Gocce.
  'drop_full': Icons.water_drop,
  'drop_opacity': Icons.opacity,
  'drop_invert': Icons.invert_colors,
};

/// Icona di [glyphId]. Fallback su un punto interrogativo se manca la entry:
/// una casella storta è meglio di un crash **dentro** il gate che l'utente sta
/// usando per disattivare qualcosa.
IconData glyphIcon(String glyphId) =>
    kGlyphIcons[glyphId] ?? Icons.help_outline;
