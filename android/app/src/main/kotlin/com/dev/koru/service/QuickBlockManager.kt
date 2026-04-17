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

    fun startQuickBlock(durationMs: Long) {
        stop()
        isPomodoroMode = false
        totalMs = durationMs
        remainingMs = durationMs
        isActive = true
        startTimer(durationMs)
        Log.i(TAG, "Quick block started: ${durationMs}ms")
    }

    fun startPomodoro(workMs: Long, breakMs: Long, cycles: Int) {
        stop()
        isPomodoroMode = true
        this.workMs = workMs
        this.breakMs = breakMs
        this.totalCycles = cycles
        this.currentCycle = 1
        this.isBreakPhase = false
        totalMs = workMs
        remainingMs = workMs
        isActive = true
        startTimer(workMs)
        Log.i(TAG, "Pomodoro started: ${workMs}ms work, ${breakMs}ms break, $cycles cycles")
    }

    fun stop() {
        timer?.cancel()
        timer = null
        isActive = false
        remainingMs = 0
        isPomodoroMode = false
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
