package com.dev.koru.browser

import com.dev.koru.db.NativeWebsiteRule

object WebsiteMatcher {
    fun matches(rule: NativeWebsiteRule, url: String, domain: String): Boolean {
        val name = rule.name.lowercase()
        if (name == domain) return true
        if (rule.blockingType == 0 && domain.endsWith(".$name")) return true
        if (rule.blockingType == 1) return if (rule.isAnywhereInUrl) url.contains(name) else domain.contains(name)
        return false
    }

    fun matchesAny(rules: List<NativeWebsiteRule>, url: String, domain: String): Boolean =
        rules.any { matches(it, url, domain) }
}
