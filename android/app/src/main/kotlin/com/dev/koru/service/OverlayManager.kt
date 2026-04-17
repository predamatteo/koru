package com.dev.koru.service

import android.content.Context
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner

/**
 * Window overlay che mostra la schermata di blocco Koru sopra qualunque app.
 * Versione Step 5 — rendering Compose hardcoded con palette Koru.
 * Step 6 refactora in versione parametrica con OverlayConfig per-app.
 */
class OverlayManager(private val context: Context) : LifecycleOwner, SavedStateRegistryOwner {

    companion object {
        private const val TAG = "OverlayManager"
    }

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateRegistryController.savedStateRegistry

    private var windowManager: WindowManager? = null
    private var overlayView: ComposeView? = null
    private var isShowing = false

    var currentPackageName: String = ""
        private set

    private val appLabelState = mutableStateOf("")
    private val profileTitleState = mutableStateOf("")

    var onReturnHome: (() -> Unit)? = null

    init {
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
    }

    fun show(packageName: String, appLabel: String, profileTitle: String) {
        if (isShowing) {
            currentPackageName = packageName
            appLabelState.value = appLabel
            profileTitleState.value = profileTitle
            return
        }

        currentPackageName = packageName
        appLabelState.value = appLabel
        profileTitleState.value = profileTitle

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }

            val composeView = ComposeView(context).apply {
                setViewTreeLifecycleOwner(this@OverlayManager)
                setViewTreeSavedStateRegistryOwner(this@OverlayManager)
                setContent {
                    BlockedScreen(
                        appLabel = appLabelState.value,
                        profileTitle = profileTitleState.value,
                        onReturnHome = { onReturnHome?.invoke() },
                    )
                }
            }

            lifecycleRegistry.currentState = Lifecycle.State.RESUMED
            windowManager?.addView(composeView, params)
            overlayView = composeView
            isShowing = true
            Log.d(TAG, "Overlay shown for $packageName")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }

    fun dismiss() {
        if (!isShowing) return
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove overlay view", e)
        } finally {
            overlayView = null
            isShowing = false
            try { lifecycleRegistry.currentState = Lifecycle.State.CREATED } catch (_: Exception) {}
            Log.d(TAG, "Overlay dismissed")
        }
    }

    fun isVisible(): Boolean = isShowing

    fun destroy() {
        dismiss()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
    }
}

@Composable
private fun BlockedScreen(
    appLabel: String,
    profileTitle: String,
    onReturnHome: () -> Unit,
) {
    // Palette Koru dark-first.
    val bgBase = Color(0xFF0E100F)
    val textPrimary = Color(0xFFE8E6E1)
    val textSecondary = Color(0xFF8B8F8A)
    val primaryAccent = Color(0xFF5C8262)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(bgBase),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(32.dp),
        ) {
            Text(text = "\uD83C\uDF3F", fontSize = 64.sp)
            Spacer(Modifier.height(24.dp))
            Text(
                text = "Take a breath",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = textPrimary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = appLabel,
                fontSize = 20.sp,
                color = textPrimary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "paused by \u201C$profileTitle\u201D",
                fontSize = 14.sp,
                color = textSecondary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(48.dp))
            Button(
                onClick = onReturnHome,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = primaryAccent),
            ) {
                Text(
                    text = "Go back",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = textPrimary,
                )
            }
        }
    }
}
