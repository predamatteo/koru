import 'package:flutter/material.dart';

/// Koru color tokens — **Material 3 Expressive · "Sage Tonal"** (dark).
///
/// Tonal, layered surfaces + a single bright sage primary and one warm sand
/// accent. The whole app references these constants directly (rather than the
/// Material [ColorScheme]), so this file is the master palette lever.
///
/// IMPORTANT — on-color inversion: [primary] and [danger] are now **bright**
/// tones (they read as accents on dark surfaces). When either is used as a
/// *filled background*, put the matching dark on-color on top ([onPrimary] /
/// [onDanger]), never [textPrimary].
class KoruColors {
  const KoruColors._();

  // ── Surfaces (tonal, layered: bg < s1 < s2 < s3) ───────────────────────
  static const Color backgroundBase = Color(0xFF0F1210); // --bg
  static const Color surface = Color(0xFF161A17); // --s1  (cards)
  static const Color surfaceContainer = Color(0xFF1D221E); // --s2  (tiles)
  static const Color surfaceElevated = Color(0xFF252B26); // --s3  (nav, chips)

  // ── Primary — bright sage ──────────────────────────────────────────────
  static const Color primary = Color(0xFFA4D6A0); // --pri
  static const Color onPrimary = Color(0xFF0B3912); // --onpri (dark)
  static const Color primaryContainer = Color(0xFF294E2E); // --pric
  static const Color onPrimaryContainer = Color(0xFFC0F3BB); // --onpric

  // ── Tertiary — warm sand (the single accent) ───────────────────────────
  static const Color tertiary = Color(0xFFE6C08C); // --ter
  static const Color onTertiary = Color(0xFF41320B); // dark
  static const Color tertiaryContainer = Color(0xFF4A3B23); // --terc
  static const Color onTertiaryContainer = Color(0xFFF6DCB0); // --onterc

  // Back-compat: the app historically called the warm accent "secondary".
  // Keep the names, point them at the sand family so existing call-sites keep
  // working with the new look.
  static const Color secondary = tertiary;
  static const Color onSecondary = onTertiary;
  static const Color secondaryContainer = tertiaryContainer;
  static const Color onSecondaryContainer = onTertiaryContainer;

  // ── Text / content ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE7EAE4); // --tx
  static const Color textSecondary = Color(0xFF8E948C); // --tx2

  // ── Outline / dividers ─────────────────────────────────────────────────
  static const Color outline = Color(0xFF333934); // --out

  // ── Error / danger — bright salmon ─────────────────────────────────────
  static const Color danger = Color(0xFFF0B4AB); // --err
  static const Color onDanger = Color(0xFF4E241E); // dark
  static const Color dangerContainer = Color(0xFF4E241E); // --errc
  static const Color onDangerContainer = Color(0xFFFFDAD4); // --onerrc

  // ── Success ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF9BD49A); // --succ
  static const Color successContainer = Color(0xFF244023);
}
