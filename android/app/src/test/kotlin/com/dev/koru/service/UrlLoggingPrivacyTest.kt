package com.dev.koru.service

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * SEC-07 regression guard.
 *
 * Le URL di navigazione complete (path + query) sono cronologia = PII per una
 * app di benessere digitale. Questo test fa uno scan STATICO del sorgente per
 * garantire che nessun `Log.*` logghi la URL completa (`fullUrl` / `full=`) e
 * che i log che espongono il dominio navigato siano gated dietro
 * `BuildConfig.DEBUG` (mai emessi in release).
 *
 * Perché uno scan del sorgente invece di un test runtime: il gate è su
 * `BuildConfig.DEBUG`, una costante compile-time che un unit test non può
 * ribaltare. Il rischio che SEC-07 protegge è "qualcuno reintroduce un
 * Log.x(... fullUrl ...)" — uno scan del sorgente lo intercetta in modo
 * deterministico e CI-enforceable.
 */
class UrlLoggingPrivacyTest {

    private fun mainKotlin(relative: String): File {
        // I test girano con cwd = module dir (android/app) oppure repo root a
        // seconda dell'invocazione; risaliamo finché troviamo il sorgente.
        val candidates = listOf(
            File("src/main/kotlin/com/dev/koru/$relative"),
            File("android/app/src/main/kotlin/com/dev/koru/$relative"),
            File("app/src/main/kotlin/com/dev/koru/$relative"),
        )
        candidates.firstOrNull { it.exists() }?.let { return it }
        // Fallback: risali dalla cwd cercando il path noto.
        var dir: File? = File(".").absoluteFile
        while (dir != null) {
            val f = File(dir, "android/app/src/main/kotlin/com/dev/koru/$relative")
            if (f.exists()) return f
            dir = dir.parentFile
        }
        throw AssertionError("Source not found for $relative (cwd=${File(".").absolutePath})")
    }

    /// Una riga di log "logga il full URL" se contiene un `Log.` e referenzia
    /// `fullUrl` o la sottostringa `full=` (il vecchio leak era
    /// `Log.i(TAG, "...full=${detected.fullUrl}")`).
    private fun logLinesLeakingFullUrl(source: String): List<String> =
        source.lineSequence()
            .map { it.trim() }
            .filter { it.startsWith("Log.") || it.contains(") Log.") }
            .filter { it.contains("fullUrl") || it.contains("full=") }
            .toList()

    @Test
    fun accessibilityService_neverLogsFullUrl() {
        val src = mainKotlin("service/KoruAccessibilityService.kt").readText()
        assertThat(logLinesLeakingFullUrl(src)).isEmpty()
    }

    @Test
    fun browserUrlDetector_neverLogsFullUrl() {
        val src = mainKotlin("browser/BrowserUrlDetector.kt").readText()
        assertThat(logLinesLeakingFullUrl(src)).isEmpty()
    }

    @Test
    fun accessibilityService_urlDetectionLogIsDebugGatedAndDomainOnly() {
        val src = mainKotlin("service/KoruAccessibilityService.kt").readText()
        // La riga che logga il dominio rilevato deve esistere, essere gated da
        // BuildConfig.DEBUG e contenere solo `domain=` (no fullUrl).
        val line = src.lineSequence()
            .map { it.trim() }
            .firstOrNull { it.contains("URL detected") }
        assertThat(line).isNotNull()
        assertThat(line!!).contains("BuildConfig.DEBUG")
        assertThat(line).contains("detected.domain")
        assertThat(line).doesNotContain("fullUrl")
    }

    @Test
    fun browserUrlDetector_domainLogsAreDebugGated() {
        val src = mainKotlin("browser/BrowserUrlDetector.kt").readText()
        // Ogni Log che interpola un `$domain` (dominio navigato = PII) deve
        // stare sulla stessa riga di un gate BuildConfig.DEBUG.
        val ungated = src.lineSequence()
            .map { it.trim() }
            .filter { it.contains("Log.") && it.contains("\$domain") }
            .filter { !it.contains("BuildConfig.DEBUG") }
            .toList()
        assertThat(ungated).isEmpty()
    }
}
