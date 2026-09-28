package com.schatz.production.managers

import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class CallState { IDLE, CALLING, CONNECTING, CONNECTED, ENDED, INCOMING, RINGING, DECLINED, BUSY, FAILED, MISSED }

class CallManager(private val tdLib: TdLibUpdateManager) {
    private val _callState = MutableStateFlow(CallState.IDLE)
    val callState: StateFlow<CallState> = _callState
    private val _isMuted = MutableStateFlow(false)
    val isMuted: StateFlow<Boolean> = _isMuted
    private val _isVideoEnabled = MutableStateFlow(true)
    val isVideoEnabled: StateFlow<Boolean> = _isVideoEnabled
    private val _isSpeaker = MutableStateFlow(false)
    val isSpeaker: StateFlow<Boolean> = _isSpeaker
    private val _duration = MutableStateFlow(0L)
    val duration: StateFlow<Long> = _duration
    private var currentCallId: Int = 0
    private var timer: java.util.Timer? = null

    fun init() {
        tdLib.onCallUpdate = { call ->
            currentCallId = call.id
            when(call.state) {
                is TdApi.CallStatePending -> _callState.value = CallState.CALLING
                is TdApi.CallStateExchangingKeys -> _callState.value = CallState.CONNECTING
                is TdApi.CallStateReady -> { _callState.value = CallState.CONNECTED; startTimer() }
                is TdApi.CallStateHangingUp -> _callState.value = CallState.ENDED
                is TdApi.CallStateDiscarded -> {
                    val discarded = call.state as TdApi.CallStateDiscarded
                    _callState.value = when(discarded.reason) {
                        is TdApi.CallDiscardReasonDeclined -> CallState.DECLINED
                        is TdApi.CallDiscardReasonMissed -> CallState.MISSED
                        is TdApi.CallDiscardReasonDisconnected -> CallState.FAILED
                        else -> CallState.ENDED
                    }
                    stopTimer()
                }
                is TdApi.CallStateError -> _callState.value = CallState.FAILED
            }
        }
    }

    fun startCall(userId: Long, isVideo: Boolean) { _callState.value = CallState.CALLING; tdLib.createCall(userId, isVideo) }
    fun acceptCall(callId: Int) { _callState.value = CallState.CONNECTING; tdLib.acceptCall(callId, TdApi.CallProtocol(true, true, 2048, 1, arrayOf("1.0"))) }
    fun endCall() { if(currentCallId != 0) tdLib.discardCall(currentCallId); _callState.value = CallState.ENDED; stopTimer() }
    fun toggleMute() { _isMuted.value = !_isMuted.value }
    fun toggleVideo() { _isVideoEnabled.value = !_isVideoEnabled.value }
    fun toggleSpeaker() { _isSpeaker.value = !_isSpeaker.value }
    fun switchCamera() {}

    private fun startTimer() {
        timer?.cancel()
        timer = java.util.Timer()
        timer?.scheduleAtFixedRate(object : java.util.TimerTask() { override fun run() { _duration.value += 1 } }, 1000, 1000)
    }
    private fun stopTimer() { timer?.cancel(); timer = null; _duration.value = 0 }
}
