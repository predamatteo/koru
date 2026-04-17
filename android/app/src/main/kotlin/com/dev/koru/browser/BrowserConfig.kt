package com.dev.koru.browser

import android.content.Context
import org.json.JSONArray

data class BrowserConfig(
    val packageName: String,
    val viewId: String,
    val viewType: Int,
    val detectionMethod: String,
    val extractionMethod: String,
    val clearUrl: Boolean,
)

object BrowserConfigLoader {
    private var configs: List<BrowserConfig>? = null
    private var browserPackages: Set<String>? = null

    fun load(context: Context): List<BrowserConfig> {
        if (configs != null) return configs!!
        val resId = context.resources.getIdentifier("browser_view_ids", "raw", context.packageName)
        if (resId == 0) return emptyList()
        val json = context.resources.openRawResource(resId).bufferedReader().readText()
        val arr = JSONArray(json)
        val result = mutableListOf<BrowserConfig>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            result.add(
                BrowserConfig(
                    packageName = o.getString("packageName"),
                    viewId = o.getString("viewId"),
                    viewType = o.getInt("viewType"),
                    detectionMethod = o.optString("detectionMethod", "VIEW_ID"),
                    extractionMethod = o.optString("extractionMethod", "TEXT"),
                    clearUrl = o.optBoolean("clearUrl", true),
                )
            )
        }
        configs = result
        browserPackages = result.filter { it.viewType == 0 }.map { it.packageName }.toSet()
        return result
    }

    fun isBrowser(context: Context, packageName: String): Boolean {
        load(context)
        return browserPackages?.contains(packageName) == true
    }

    fun getConfigsForPackage(context: Context, packageName: String): List<BrowserConfig> =
        load(context).filter { it.packageName == packageName && it.viewType == 0 }
}
