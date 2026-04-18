package com.dev.koru.service

import android.content.Context
import android.os.CountDownTimer
import android.util.Log
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.db.NativeDatabase
import org.json.JSONObject

class QuickBlockManager {
    companion object {
        private const val TAG = "QuickBlockManager"
    }

    /// applicationContext iniettato da [LockForegroundService.onCreate] per
    /// poter persistere lo snapshot di stato via [QuickBlockStore]. Lo store
    /// è necessario perché [KoruAccessibilityService] vive in un altro
    /// processo (`:accessibility`) e non vede la static state di questo
    /// oggetto: deve leggerla da disco.
    @Volatile
    private var appContext: Context? = null

    fun attachContext(context: Context) {
        appContext = context.applicationContext
    }

    private var timer: CountDownTimer? = null

    var isActive = false
        private set
    var totalMs: Long = 0
        private set
    var remainingMs: Long = 0
        private set

    private var isPomodoroMode = false
    private var workMs: Long = 0
    private var breakMs: Long = 0
    private var totalCycles: Int = 0
    private var currentCycle: Int = 0
    private var isBreakPhase = false
    private var phaseStartedAt: Long = 0

    /// Package whitelist corrente (app che restano usabili durante
    /// quick-block / pomodoro-work). Tutte le altre app sono bloccate.
    @Volatile
    var whitelist: Set<String> = emptySet()
        private set

    /**
     * True quando un blocco "catch-all" è in corso e la app `packageName`
     * NON è nella whitelist → AccessibilityService deve bloccarla.
     * Durante la fase break del pomodoro ritorna false (l'utente può
     * usare il telefono normalmente nei break).
     *
     * NB: funziona solo nel processo main. Dal processo `:accessibility`
     * usare [QuickBlockStore.read] e [QuickBlockStore.Snapshot.shouldBlock].
     */
    fun shouldBlockEverythingExceptWhitelist(packageName: String): Boolean {
        if (!isActive) return false
        if (isPomodoroMode && isBreakPhase) return false
        return !whitelist.contains(packageName)
    }

    fun startQuickBlock(durationMs: Long, whitelist: Set<String> = emptySet()) {
        stop()
        isPomodoroMode = false
        totalMs = durationMs
        remainingMs = durationMs
        this.whitelist = whitelist
        isActive = true
        phaseStartedAt = System.currentTimeMillis()
        persistSnapshot(durationMs)
        startTimer(durationMs)
        Log.i(TAG, "Quick block started: ${durationMs}ms, whitelist=${whitelist.size} apps")
    }

    fun startPomodoro(
        workMs: Long,
        breakMs: Long,
        cycles: Int,
        whitelist: Set<String> = emptySet(),
    ) {
        stop()
        isPomodoroMode = true
        this.workMs = workMs
        this.breakMs = breakMs
        this.totalCycles = cycles
        this.currentCycle = 1
        this.isBreakPhase = false
        this.whitelist = whitelist
        totalMs = workMs
        remainingMs = workMs
        isActive = true
        phaseStartedAt = System.currentTimeMillis()
        persistSnapshot(workMs)
        startTimer(workMs)
        Log.i(TAG, "Pomodoro started: ${workMs}ms work, ${breakMs}ms break, $cycles cycles, whitelist=${whitelist.size}")
    }

    fun stop() {
        recordFocusIfApplicable()
        timer?.cancel()
        timer = null
        isActive = false
        remainingMs = 0
        isPomodoroMode = false
        whitelist = emptySet()
        clearSnapshot()
        sendTickEvent()
        Log.i(TAG, "Quick block/pomodoro stopped")
    }

    /**
     * Se la fase corrente è una sessione di focus (quick-block o pomodoro
     * work), registra la durata maturata su `focus_usage_events`.
     * Fasi <30s sono ignorate come rumore (accidental tap).
     */
    private fun recordFocusIfApplicable() {
        if (!isActive) return
        if (isBreakPhase) return
        if (phaseStartedAt <= 0) return
        val ctx = appContext ?: return
        val durationMs = System.currentTimeMillis() - phaseStartedAt
        if (durationMs < 30_000) return
        try {
            NativeDatabase.insertFocusUsageEvent(ctx, durationMs, System.currentTimeMillis())
            Log.i(TAG, "Focus session recorded: ${durationMs}ms")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to record focus session: ${e.message}")
        }
    }

    private fun startTimer(durationMs: Long) {
        timer?.cancel()
        timer = object : CountDownTimer(durationMs, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                remainingMs = millisUntilFinished
                sendTickEvent()
            }

            override fun onFinish() {
                remainingMs = 0
                if (isPomodoroMode) {
                    handlePomodoroPhaseEnd()
                } else {
                    recordFocusIfApplicable()
                    isActive = false
                    clearSnapshot()
                    sendTickEvent()
                    Log.i(TAG, "Quick block finished")
                }
            }
        }.start()
    }

    private fun handlePomodoroPhaseEnd() {
        if (isBreakPhase) {
            // break → work: niente da registrare per la break phase.
            currentCycle++
            if (currentCycle > totalCycles) {
                isActive = false
                clearSnapshot()
                sendTickEvent()
                Log.i(TAG, "Pomodoro complete: all $totalCycles cycles done")
                return
            }
            isBreakPhase = false
            totalMs = workMs
            remainingMs = workMs
            phaseStartedAt = System.currentTimeMillis()
            persistSnapshot(workMs)
            startTimer(workMs)
            Log.i(TAG, "Pomodoro cycle $currentCycle: focus phase")
        } else {
            // work → break (o completion): fase di focus appena chiusa, registra.
            recordFocusIfApplicable()
            if (currentCycle >= totalCycles) {
                isActive = false
                clearSnapshot()
                sendTickEvent()
                Log.i(TAG, "Pomodoro complete")
                return
            }
            isBreakPhase = true
            totalMs = breakMs
            remainingMs = breakMs
            phaseStartedAt = System.currentTimeMillis()
            persistSnapshot(breakMs)
            startTimer(breakMs)
            Log.i(TAG, "Pomodoro cycle $currentCycle: break phase")
        }
        sendTickEvent()
    }

    private fun persistSnapshot(phaseDurationMs: Long) {
        val ctx = appContext ?: run {
            Log.w(TAG, "appContext not attached — cannot persist snapshot")
            return
        }
        val expiresAt = if (phaseDurationMs > 0) System.currentTimeMillis() + phaseDurationMs else 0L
        QuickBlockStore.save(
            ctx,
            QuickBlockStore.Snapshot(
                isActive = isActive,
                isPomodoroMode = isPomodoroMode,
                isBreakPhase = isBreakPhase,
                expiresAt = expiresAt,
                whitelist = whitelist,
            ),
        )
    }

    private fun clearSnapshot() {
        val ctx = appContext ?: return
        QuickBlockStore.clear(ctx)
    }

    private fun sendTickEvent() {
        val json = JSONObject().apply {
            put("type", "QUICK_BLOCK_TICK")
            put("remainingMs", remainingMs)
            put("totalMs", totalMs)
            put("isPomodoroBreak", isBreakPhase)
            put("isActive", isActive)
            put("currentCycle", currentCycle)
            put("totalCycles", totalCycles)
        }
        ServiceEventChannel.sendEvent(json.toString())
    }
}
