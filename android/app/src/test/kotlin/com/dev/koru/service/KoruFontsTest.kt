package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Tests for [KoruFonts.assetPath] — la mappatura PURA `KoruFont.id` → path
 * dell'asset Flutter. È il contratto interno tra la preferenza Dart
 * (`lib/core/theme/font_catalog.dart`) e il caricamento nativo del `.ttf`.
 *
 * [KoruFonts.resolve] non è coperto qui: dipende da `Typeface.createFromAsset`
 * e dagli asset Flutter reali (non presenti nell'ambiente JVM/Robolectric) →
 * verificato on-device. Qui blindiamo che la tabella id→path resti allineata
 * all'enum Dart e ai file dichiarati nel `pubspec.yaml`.
 */
class KoruFontsTest {

    @Test
    fun assetPath_systemFontId_isNull() {
        // id 0 = System → nessun asset → font di sistema.
        assertThat(KoruFonts.assetPath(0)).isNull()
    }

    @Test
    fun assetPath_customFontIds_mapToExpectedTtf() {
        assertThat(KoruFonts.assetPath(1))
            .isEqualTo("flutter_assets/assets/fonts/Goldman-Regular.ttf")
        assertThat(KoruFonts.assetPath(2))
            .isEqualTo("flutter_assets/assets/fonts/Orbitron-Regular.ttf")
        assertThat(KoruFonts.assetPath(3))
            .isEqualTo("flutter_assets/assets/fonts/ArchitectsDaughter-Regular.ttf")
        assertThat(KoruFonts.assetPath(4))
            .isEqualTo("flutter_assets/assets/fonts/OpenDyslexic-Regular.otf")
    }

    @Test
    fun assetPath_unknownFontId_isNull() {
        assertThat(KoruFonts.assetPath(5)).isNull()
        assertThat(KoruFonts.assetPath(-1)).isNull()
        assertThat(KoruFonts.assetPath(99)).isNull()
    }

    /// L'estensione segue l'upstream del font e non e' uniforme: OpenDyslexic
    /// e' distribuito solo in OTF, gli altri tre in TTF. Convertirlo creerebbe
    /// una versione modificata, vietata dal Reserved Font Name della sua OFL
    /// (vedi assets/fonts/LICENSES.md) — quindi l'asserzione e' sul set di
    /// estensioni ammesse, non su una sola.
    @Test
    fun assetPath_allCustomFonts_targetFlutterAssetsFontsDir() {
        for (id in 1..4) {
            val path = KoruFonts.assetPath(id)
            assertThat(path).isNotNull()
            assertThat(path).startsWith("flutter_assets/assets/fonts/")
            assertThat(path!!.substringAfterLast('.')).isIn(listOf("ttf", "otf"))
        }
    }
}
