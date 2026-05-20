package com.dev.koru.browser

import com.dev.koru.db.NativeWebsiteRule

/**
 * Decide se una URL rilevata nella URL bar di un browser matcha una delle
 * regole configurate nei profili attivi.
 *
 * Strategy aggiornata (FIX A15 — bug di over-matching):
 *  - `blockingType == 0` (domain match): matcha SOLO se il dominio rilevato
 *    e' esattamente la regola, oppure se la regola e' un suffisso parent
 *    domain. NIENTE `.contains()` sull'URL completa, che faceva matchare
 *    es. `news.com` su `https://example.com/?ref=news.com/path` (URL
 *    contiene `news.com` come query string), oppure `bbc.co.uk` su
 *    `nobbc.co.uk.example.com`. Le rule non-domain (anti-keyword) usano
 *    `blockingType == 1`.
 *  - `blockingType == 1` (keyword): `isAnywhereInUrl` decide se cerca nella
 *    URL completa o solo nel dominio. Resta `.contains()` (intenzionale).
 *
 * Estrazione domain dall'URL e' centralizzata in [extractDomain] cosi'
 * il caller puo' passare anche un URL "raw" (la signature pubblica
 * accetta sia domain che fullUrl, manteniamo backward compat).
 */
object WebsiteMatcher {
    fun matches(rule: NativeWebsiteRule, url: String, domain: String): Boolean {
        val ruleLower = rule.name.lowercase().trim()
        if (ruleLower.isEmpty()) return false

        val urlLower = url.lowercase()
        // Se chi chiama ha gia' estratto il domain lo usiamo, altrimenti
        // proviamo a estrarlo dall'url (defensive).
        val domainLower = domain.lowercase().ifEmpty {
            extractDomain(urlLower).orEmpty()
        }

        return when (rule.blockingType) {
            0 -> {
                // Domain match stretto: exact OR subdomain di rule.
                // Esempi:
                //   rule="facebook.com" matcha "facebook.com", "m.facebook.com"
                //   rule="facebook.com" NON matcha "nofacebook.com",
                //     "facebook.com.evil.com", "example.com/?q=facebook.com".
                domainLower == ruleLower || domainLower.endsWith(".$ruleLower")
            }
            1 -> {
                if (rule.isAnywhereInUrl) urlLower.contains(ruleLower) else domainLower.contains(ruleLower)
            }
            else -> false
        }
    }

    fun matchesAny(rules: List<NativeWebsiteRule>, url: String, domain: String): Boolean =
        rules.any { matches(it, url, domain) }

    /// Come [matchesAny] ma ritorna la prima regola che matcha (o null).
    /// Il caller usa `rule.name` (il pattern del dominio bloccato) come chiave
    /// del bypass per-dominio: e' stabile rispetto alle varianti
    /// www/sottodominio della URL rilevata (es. sia "reddit.com" che
    /// "old.reddit.com" matchano la regola "reddit.com" → stessa chiave).
    fun firstMatch(rules: List<NativeWebsiteRule>, url: String, domain: String): NativeWebsiteRule? =
        rules.firstOrNull { matches(it, url, domain) }

    /// Estrae il domain (host) da una URL stringa. Strip di schema (http/https),
    /// path (`/...`), porta (`:8080`). Ritorna null se vuoto.
    private fun extractDomain(url: String): String? {
        val withoutProtocol = url.substringAfter("://", url)
        val withoutPath = withoutProtocol.substringBefore("/")
        val withoutPort = withoutPath.substringBefore(":")
        return withoutPort.ifEmpty { null }
    }
}
