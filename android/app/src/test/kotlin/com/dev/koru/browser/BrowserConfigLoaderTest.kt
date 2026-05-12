package com.dev.koru.browser

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.lang.reflect.Modifier

/**
 * Robolectric tests for [BrowserConfigLoader].
 *
 * Loads `res/raw/browser_view_ids.json` from the actual app resources
 * (shipped in the prod APK) and verifies parse + filter semantics.
 *
 * The loader caches its result in a singleton, so we reset that cache
 * via reflection between tests to keep them order-independent.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class BrowserConfigLoaderTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        resetLoaderCache()
    }

    /** Clears the private singleton cache between tests via reflection. */
    private fun resetLoaderCache() {
        val cls = BrowserConfigLoader::class.java
        for (fieldName in arrayOf("configs", "browserPackages")) {
            try {
                val f = cls.getDeclaredField(fieldName)
                if (!Modifier.isStatic(f.modifiers)) f.isAccessible = true
                f.isAccessible = true
                f.set(BrowserConfigLoader, null)
            } catch (_: Throwable) {
                // Field name may differ across refactors — ignore silently.
            }
        }
    }

    @Test
    fun load_returnsNonEmptyList() {
        val configs = BrowserConfigLoader.load(context)
        assertThat(configs).isNotEmpty()
    }

    @Test
    fun load_parsesExpectedFields() {
        val configs = BrowserConfigLoader.load(context)
        val chrome = configs.firstOrNull { it.packageName == "com.android.chrome" }
        assertThat(chrome).isNotNull()
        // Every config must have a non-blank viewId + non-blank detection method.
        configs.forEach { cfg ->
            assertThat(cfg.viewId).isNotEmpty()
            assertThat(cfg.detectionMethod).isNotEmpty()
            assertThat(cfg.extractionMethod).isNotEmpty()
        }
    }

    @Test
    fun isBrowser_chromeIsKnown() {
        assertThat(BrowserConfigLoader.isBrowser(context, "com.android.chrome")).isTrue()
    }

    @Test
    fun isBrowser_unknownPackageIsFalse() {
        assertThat(
            BrowserConfigLoader.isBrowser(context, "com.example.nonexistent")
        ).isFalse()
    }

    @Test
    fun getConfigsForPackage_filtersOnViewTypeZero() {
        val chromeConfigs = BrowserConfigLoader.getConfigsForPackage(
            context, "com.android.chrome",
        )
        assertThat(chromeConfigs).isNotEmpty()
        // viewType==1 entries (incognito badges) must be excluded.
        chromeConfigs.forEach { cfg ->
            assertThat(cfg.viewType).isEqualTo(0)
            assertThat(cfg.packageName).isEqualTo("com.android.chrome")
        }
    }

    @Test
    fun getConfigsForPackage_unknownPackageReturnsEmpty() {
        val result = BrowserConfigLoader.getConfigsForPackage(
            context, "com.example.nonexistent",
        )
        assertThat(result).isEmpty()
    }

    @Test
    fun load_isCached_secondCallReturnsSameInstance() {
        val first = BrowserConfigLoader.load(context)
        val second = BrowserConfigLoader.load(context)
        // The loader returns the cached list, so reference equality holds.
        assertThat(second).isSameInstanceAs(first)
    }
}
