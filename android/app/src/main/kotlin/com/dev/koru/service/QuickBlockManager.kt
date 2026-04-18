package com.dev.koru.service

import android.os.CountDownTimer
import android.util.Log
import com.dev.koru.channels.ServiceEventChannel
import org.json.JSONObject

class QuickBlockManager {
    companion object {
        private const val TAG = "QuickBlockManager"
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
        startTimer(workMs)
        Log.i(TAG, "Pomodoro started: ${workMs}ms work, ${breakMs}ms break, $cycles cycles, whitelist=${whitelist.size}")
    }

    fun stop() {
        timer?.cancel()
        timer = null
        isActive = false
        remainingMs = 0
        isPomodoroMode = false
        whitelist = emptySet()
        sendTickEvent()
        Log.i(TAG, "Quick block/pomodoro stopped")
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
                    isActive = false
                    sendTickEvent()
                    Log.i(TAG, "Quick block finished")
                }
            }
        }.start()
    }

    private fun handlePomodoroPhaseEnd() {
        if (isBreakPhase) {
            currentCycle++
            if (currentCycle > totalCycles) {
                isActive = false
                sendTickEvent()
                Log.i(TAG, "Pomodoro complete: all $totalCycles cycles done")
                return
            }
            isBreakPhase = false
            totalMs = workMs
            remainingMs = workMs
            startTimer(workMs)
            Log.i(TAG, "Pomodoro cycle $currentCycle: focus phase")
        } else {
            if (currentCycle >= totalCycles) {
                isActive = false
                sendTickEvent()
                Log.i(TAG, "Pomodoro complete")
                return
            }
            isBreakPhase = true
            totalMs = breakMs
            remainingMs = breakMs
            startTimer(breakMs)
            Log.i(TAG, "Pomodoro cycle $currentCycle: break phase")
        }
        sendTickEvent()
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
