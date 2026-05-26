package com.dev.koru.strictmode

import android.os.SystemClock
import java.security.SecureRandom

/**
 * Token monouso per autorizzare lato NATIVE un downgrade della strict-mode mask
 * (SEC-01).
 *
 * Problema (SEC-01, Critical): `setStrictModeOptions` accettava QUALSIASI mask,
 * azzeramento incluso, senza autenticazione. Il gate del backdoor code esisteva
 * SOLO nell'UI Dart → un attaccante (l'utente stesso "in crisi", o un'app
 * co-installata che parla col channel) poteva invocare `setStrictModeOptions(0)`
 * e bypassare l'intero strict mode senza code/lockout/device-admin.
 *
 * Soluzione: il native emette un token monouso SOLO dopo una validazione
 * riuscita del backdoor code ([validateBackdoorCode] → [issue]); ogni mask
 * change che SPEGNE un bit attivo deve presentare quel token, che viene
 * [consume]-ato atomicamente (single-use, no replay). Alzare la mask (aggiungere
 * restrizioni) resta non autenticato — è la direzione fail-secure.
 *
 * Proprietà di sicurezza:
 * - **Monotonic-bound TTL**: il token scade [TTL_MS] dopo l'emissione misurati
 *   su [SystemClock.elapsedRealtime] (clock monotonico, non riavvolgibile
 *   cambiando l'orologio di sistema). Spostare il wall clock NON estende il
 *   token; `elapsedRealtime` avanza sempre, quindi il token scade comunque.
 * - **Single outstanding**: emettere un nuovo token invalida il precedente
 *   (un solo token vivo alla volta).
 * - **Single-use atomico**: [consume] confronta + cancella sotto lock, così lo
 *   stesso token non può autorizzare due downgrade (no replay).
 * - **Opaco & ad alta entropia**: 256 bit da [SecureRandom], confronto a tempo
 *   costante (no timing side-channel; comunque non brute-forzabile).
 * - **Non persistito**: vive solo in memoria di processo. Un riavvio del
 *   processo invalida ogni token ⇒ serve ri-autenticarsi (fail-secure).
 *
 * Scope: emissione e consumo avvengono nello STESSO processo (il main, via
 * [com.dev.koru.channels.StrictModeMethodChannel] agganciato all'Activity),
 * quindi basta la sincronizzazione intra-processo. Non serve il lock
 * cross-process di [com.dev.koru.service.BypassStore].
 */
object UnblockTokenStore {

    /// Time-to-live del token, in ms di clock monotonico. Volutamente breve:
    /// copre il round-trip "valida code → chiama setStrictModeOptions" e niente
    /// più, per minimizzare la finestra di replay/uso improprio.
    const val TTL_MS: Long = 60_000L

    private val secureRandom = SecureRandom()
    private val lock = Any()

    private var currentToken: String? = null
    private var issuedElapsedMs: Long = 0L

    /// Emette un nuovo token monouso e ne ritorna il valore. Invalida qualsiasi
    /// token precedente. [nowElapsedMs] iniettabile per i test (default: clock
    /// monotonico reale).
    fun issue(nowElapsedMs: Long = SystemClock.elapsedRealtime()): String {
        synchronized(lock) {
            val token = randomToken()
            currentToken = token
            issuedElapsedMs = nowElapsedMs
            return token
        }
    }

    /// Consuma [token] se è quello corrente e non è scaduto. Atomico: in caso di
    /// match valido cancella il token (single-use) e ritorna true; altrimenti
    /// (token nullo/vuoto, mismatch, scaduto) ritorna false e — se scaduto —
    /// pulisce lo slot. [nowElapsedMs] iniettabile per i test.
    fun consume(token: String?, nowElapsedMs: Long = SystemClock.elapsedRealtime()): Boolean {
        synchronized(lock) {
            val expected = currentToken
            if (expected == null || token.isNullOrEmpty()) return false

            // Scadenza su clock monotonico: nowElapsed può solo avanzare, quindi
            // un wall-clock jump non aiuta. issuedElapsed "futuro" (nowElapsed <
            // issued, possibile solo con bug/overflow) ⇒ trattato come scaduto.
            val age = nowElapsedMs - issuedElapsedMs
            if (age < 0L || age > TTL_MS) {
                // Token scaduto: scartalo (no riuso dopo TTL).
                clearLocked()
                return false
            }

            if (!constantTimeEquals(expected, token)) return false

            // Match valido entro TTL → consuma (single-use).
            clearLocked()
            return true
        }
    }

    /// Invalida esplicitamente qualsiasi token in sospeso (es. su logout/disable
    /// UI). Idempotente.
    fun invalidate() {
        synchronized(lock) { clearLocked() }
    }

    private fun clearLocked() {
        currentToken = null
        issuedElapsedMs = 0L
    }

    private fun randomToken(): String {
        val bytes = ByteArray(32) // 256 bit
        secureRandom.nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].code xor b[i].code)
        }
        return result == 0
    }
}
