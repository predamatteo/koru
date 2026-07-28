package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * Guard strutturale del silenziamento media.
 *
 * La causa del bug "overlay su ma l'audio parte comunque" non era un algoritmo
 * sbagliato: era che UN path di blocco su otto era strumentato e gli altri no.
 * Un unit test non può istanziare [KoruAccessibilityService] (è un Service
 * Android da 2300 righe), quindi la regola vive come scan del sorgente —
 * deterministico e CI-enforceable, stesso ragionamento di
 * [UrlLoggingPrivacyTest].
 *
 * La regola: **ogni `overlayManager?.show(...)` deve essere seguito, entro
 * poche righe, da un silenziamento**. Se aggiungi un nuovo path di blocco e
 * dimentichi il silenziamento, questo test te lo dice.
 */
class MediaSilenceParityTest {

    private fun mainKotlin(relative: String): File {
        // I test girano con cwd = module dir (android/app) oppure repo root a
        // seconda dell'invocazione; risaliamo finché troviamo il sorgente.
        val candidates = listOf(
            File("src/main/kotlin/com/dev/koru/$relative"),
            File("android/app/src/main/kotlin/com/dev/koru/$relative"),
            File("app/src/main/kotlin/com/dev/koru/$relative"),
        )
        candidates.firstOrNull { it.exists() }?.let { return it }
        var dir: File? = File(".").absoluteFile
        while (dir != null) {
            val f = File(dir, "android/app/src/main/kotlin/com/dev/koru/$relative")
            if (f.exists()) return f
            dir = dir.parentFile
        }
        throw AssertionError("Source not found for $relative (cwd=${File(".").absolutePath})")
    }

    /// Righe di `overlayManager?.show(` la cui chiamata NON è seguita da un
    /// silenziamento entro [window] righe dalla parentesi di chiusura.
    ///
    /// Lo `show` è multi-riga (named arguments), quindi cerchiamo il
    /// silenziamento in una finestra generosa a partire dalla riga dello show.
    private fun showsWithoutSilence(source: String, window: Int = 22): List<Int> {
        val lines = source.lines()
        val offenders = mutableListOf<Int>()
        lines.forEachIndexed { idx, line ->
            if (!line.contains("overlayManager?.show(")) return@forEachIndexed
            val slice = lines.subList(idx, minOf(idx + window, lines.size))
            val silenced = slice.any {
                it.contains("silenceMediaFor(") || it.contains("mediaSilencer?.silence(")
            }
            if (!silenced) offenders.add(idx + 1) // 1-based, come l'editor
        }
        return offenders
    }

    @Test
    fun accessibilityService_everyBlockOverlaySilencesMedia() {
        val src = mainKotlin("service/KoruAccessibilityService.kt").readText()
        assertThat(showsWithoutSilence(src)).isEmpty()
    }

    @Test
    fun lockForegroundService_everyBlockOverlaySilencesMedia() {
        // Il path di backup è attivo quando l'a11y service è stato ucciso
        // dall'OEM: la parità qui non è cosmetica.
        val src = mainKotlin("service/LockForegroundService.kt").readText()
        assertThat(showsWithoutSilence(src)).isEmpty()
    }

    @Test
    fun bothServices_actuallyHaveBlockOverlays() {
        // Sanity: se un refactor rinominasse `overlayManager?.show(`, i due
        // test sopra passerebbero a vuoto senza controllare nulla.
        val a11y = mainKotlin("service/KoruAccessibilityService.kt").readText()
        val backup = mainKotlin("service/LockForegroundService.kt").readText()
        assertThat(a11y.split("overlayManager?.show(").size - 1).isAtLeast(8)
        assertThat(backup.split("overlayManager?.show(").size - 1).isAtLeast(3)
    }

    @Test
    fun noRawAudioFocusOutsideThePort() {
        // L'unico punto autorizzato a parlare con AudioManager è
        // AndroidAudioFocusPort. Il vecchio codice inline nel service è
        // esattamente ciò che ha reso il bug invisibile per tanto tempo:
        // il valore di ritorno di requestAudioFocus veniva scartato.
        listOf(
            "service/KoruAccessibilityService.kt",
            "service/LockForegroundService.kt",
            "service/OverlayManager.kt",
            "service/LockRunnable.kt",
        ).forEach { rel ->
            val src = mainKotlin(rel).readText()
            assertThat(src).doesNotContain("requestAudioFocus")
            assertThat(src).doesNotContain("abandonAudioFocus")
        }
    }

    @Test
    fun dismissAlwaysReleasesTheSilence() {
        // Invariante: silenzio detenuto <=> overlay di blocco visibile.
        // Ogni `overlayManager?.dismiss()` deve stare dentro dismissOverlay()
        // oppure essere accompagnato da un rilascio esplicito nelle vicinanze.
        listOf(
            "service/KoruAccessibilityService.kt",
            "service/LockForegroundService.kt",
        ).forEach { rel ->
            val lines = mainKotlin(rel).readText().lines()
            val offenders = mutableListOf<Int>()
            lines.forEachIndexed { idx, line ->
                if (!line.contains("overlayManager?.dismiss()")) return@forEachIndexed
                // La definizione di dismissOverlay() è l'unica autorizzata a
                // chiamare dismiss() "nuda": è lei a fare il release.
                val inHelper = lines.subList(maxOf(0, idx - 3), idx)
                    .any { it.contains("fun dismissOverlay(") }
                if (inHelper) return@forEachIndexed
                val near = lines.subList(maxOf(0, idx - 6), minOf(idx + 7, lines.size))
                val released = near.any {
                    it.contains("mediaSilencer?.release") || it.contains("endOverlayOverApp(")
                }
                if (!released) offenders.add(idx + 1)
            }
            assertThat(offenders).isEmpty()
        }
    }
}
