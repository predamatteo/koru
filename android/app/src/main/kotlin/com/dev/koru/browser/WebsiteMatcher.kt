package com.dev.koru.browser

import com.dev.koru.db.NativeWebsiteRule

/**
 * Decide se una URL rilevata nella URL bar di un browser matcha una delle
 * regole configurate nei profili attivi.
 *
 * Strategia (porting da ascent, che ha matching collaudato):
 *  - `blockingType == 0` (domain match): matcha se il dominio è esattamente
 *    la regola, oppure è un subdominio (es. "m.facebook.com" per rule
 *    "facebook.com"), oppure la URL completa contiene il nome regola
 *    (fallback permissivo — copre URL bar che mostrano "https://facebook.com/path"
 *    anziché solo il dominio).
 *  - `blockingType == 1` (keyword): `isAnywhereInUrl` decide se cerca nella
 *    URL completa o solo nel dominio.
 */
object WebsiteMatcher {
    fun matches(rule: NativeWebsiteRule, url: String, domain: String): Boolean {
        val name = rule.name.lowercase().trim()
        if (name.isEmpty()) return false

        val urlLower = url.lowercase()
        val domainLower = domain.lowercase()

        return when (rule.blockingType) {
            0 -> {
                // Domain match (default): exact, subdomain, or URL contains name.
                // L'ultimo fallback è ciò che rende il blocker robusto se
                // l'extractor ci dà una URL completa (non solo il dominio).
                name == domainLower ||
                    domainLower.endsWith(".$name") ||
                    urlLower.contains(name)
            }
            1 -> {
                if (rule.isAnywhereInUrl) urlLower.contains(name) else domainLower.contains(name)
            }
            else -> false
        }
    }

    fun matchesAny(rules: List<NativeWebsiteRule>, url: String, domain: String): Boolean =
        rules.any { matches(it, url, domain) }
}
