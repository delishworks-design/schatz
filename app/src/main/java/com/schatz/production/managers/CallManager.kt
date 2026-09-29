package com.schatz.production.managers

import android.content.Context
import android.util.Log
import com.schatz.production.voip.CallAudioRouter
import com.schatz.production.voip.TgCallsBridge
import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class CallState { IDLE, CALLING, CONNECTING, CONNECTED, ENDED, INCOMING, RINGING, DECLINED, BUSY, FAILED, MISSED }

/** States after which no call is live any more. The UI must leave the call screen on these. */
val TERMINAL_CALL_STATES = setOf(CallState.ENDED, CallState.DECLINED, CallState.MISSED, CallState.FAILED, CallState.BUSY)

/** True when a call is live and the call UI (not the chat) owns the screen. */
fun CallState.isLive(): Boolean = this != CallState.IDLE && this !in TERMINAL_CALL_STATES

class CallManager(private val tdLib: TdLibUpdateManager, private val appContext: Context? = null) {
    companion object { const val TAG = "SchatzCall" }

    private val _callState = MutableStateFlow(CallState.IDLE)
    val callState: StateFlow<CallState> = _callState
    private val _isMuted = MutableStateFlow(false)
    val isMuted: StateFlow<Boolean> = _isMuted
    private val _isVideoEnabled = MutableStateFlow(false)
    val isVideoEnabled: StateFlow<Boolean> = _isVideoEnabled
    private val _isSpeaker = MutableStateFlow(false)
    val isSpeaker: StateFlow<Boolean> = _isSpeaker
    private val _duration = MutableStateFlow(0L)
    val duration: StateFlow<Long> = _duration

    // Exposed so the UI and the notification builder can act on a real call. Previously this was a
    // private field, so every caller passed a hardcoded 0 to the notification.
    private val _currentCallId = MutableStateFlow(0)
    val currentCallId: StateFlow<Int> = _currentCallId

    private val _isIncoming = MutableStateFlow(false)
    val isIncoming: StateFlow<Boolean> = _isIncoming

    private val _peerId = MutableStateFlow(0L)
    val peerId: StateFlow<Long> = _peerId

    // The real TDLib error text of the last failed call, rendered by the call screen. Without
    // this a rejected CreateCall showed "Call failed" and nothing else, so there was no way to
    // tell a bad username from a network drop from a server-side rejection.
    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError

    /**
     * Everything tgcalls needs once the keys are exchanged: relay servers, the shared encryption
     * key and the JSON config. The previous code discarded all of it on the floor when the state
     * became Ready, which is why no media could ever flow. Phase 3 feeds this into tgcalls.
     */
    class CallReadyInfo(
        val encryptionKey: ByteArray,
        val servers: Array<TdApi.CallServer>,
        val config: String,
        val allowP2p: Boolean,
        val emojis: Array<String>
    )

    private val _readyInfo = MutableStateFlow<CallReadyInfo?>(null)
    val readyInfo: StateFlow<CallReadyInfo?> = _readyInfo

    private var timer: java.util.Timer? = null
    private val isOutgoingCall = java.util.concurrent.atomic.AtomicBoolean(false)

    fun init() {
        tdLib.onCallUpdate = { call ->
            if (call.id != 0) _currentCallId.value = call.id
            if (call.userId != 0L) _peerId.value = call.userId
            // TDLib reports the video flag on the call itself. Trusting it keeps the notification,
            // the call screen and the history row from all disagreeing.
            _isVideoEnabled.value = call.isVideo

            when (call.state) {
                // A pending call is CALLING for the caller and RINGING for the callee. TDLib sends
                // CallStatePending for both, so isOutgoing is the only way to tell them apart.
                is TdApi.CallStatePending ->
                    if (call.isOutgoing) _callState.value = CallState.CALLING
                    else { isOutgoingCall.set(false); _isIncoming.value = true; _callState.value = CallState.RINGING }

                is TdApi.CallStateExchangingKeys -> _callState.value = CallState.CONNECTING

                is TdApi.CallStateReady -> {
                    // Hold on to everything tgcalls needs. Previously these fields were dropped,
                    // so the app had keys/servers but never used them - zero media flowed.
                    val ready = call.state as TdApi.CallStateReady
                    _readyInfo.value = CallReadyInfo(
                        encryptionKey = ready.encryptionKey,
                        servers = ready.servers,
                        config = ready.config,
                        allowP2p = ready.allowP2p,
                        emojis = ready.emojis
                    )
                    _callState.value = CallState.CONNECTED
                    if (timer == null) startTimer()
                    startMediaEngine(ready)
                }

                is TdApi.CallStateHangingUp -> {
                    _callState.value = CallState.ENDED
                    stopTimer(preserveDuration = true)
                    teardownMedia()
                }

                is TdApi.CallStateDiscarded -> {
                    val discarded = call.state as? TdApi.CallStateDiscarded
                    _callState.value = when (discarded?.reason) {
                        is TdApi.CallDiscardReasonDeclined -> CallState.DECLINED
                        is TdApi.CallDiscardReasonMissed -> CallState.MISSED
                        is TdApi.CallDiscardReasonDisconnected -> CallState.FAILED
                        else -> CallState.ENDED
                    }
                    stopTimer(preserveDuration = true)
                    teardownMedia()
                }

                is TdApi.CallStateError -> {
                    // CallStateError carries the actual error, which used to be thrown away.
                    _lastError.value = (call.state as TdApi.CallStateError).error?.message
                    _callState.value = CallState.FAILED
                    stopTimer(preserveDuration = true)
                    teardownMedia()
                }
            }
        }
        // Only genuine call-request failures reach this channel (see TdLibUpdateManager). The
        // old handler listened to the global onError, so a failed getUser while idle pushed a
        // fake FAILED call into the history, and a rejected CreateCall during CALLING was
        // ignored because CALLING is "live" - the screen then hung on Calling... forever.
        tdLib.onCallError = { err ->
            val state = _callState.value
            if (state == CallState.CALLING || state == CallState.CONNECTING || state == CallState.RINGING) {
                _lastError.value = err.message
                _callState.value = CallState.FAILED
                stopTimer(preserveDuration = true)
            }
        }
        // Phase 3: outbound leg (tgcalls -> TDLib relay) and inbound leg (TDLib -> tgcalls).
        TgCallsBridge.onSignalingOut = { data ->
            val callId = _currentCallId.value
            if (callId != 0) tdLib.sendCallSignalingData(callId, data)
        }
        // tgcalls died while TDLib still thinks the call is up: surface it as a real failure
        // instead of a silent, forever-muted call.
        TgCallsBridge.onError = { message ->
            val state = _callState.value
            if (state.isLive()) {
                Log.e(TAG, "media engine failed: $message")
                _lastError.value = message
                _callState.value = CallState.FAILED
                stopTimer(preserveDuration = true)
                teardownMedia()
            }
        }
        tdLib.onCallSignalingData = { callId, data ->
            Log.d(TAG, "signaling in: call=$callId bytes=${data.size}")
            TgCallsBridge.sendSignaling(data)
        }
    }

    fun startCall(userId: Long, isVideo: Boolean) {
        _duration.value = 0
        _lastError.value = null
        _isIncoming.value = false
        isOutgoingCall.set(true)
        _callState.value = CallState.CALLING
        tdLib.createCall(userId, isVideo)
    }

    /** Answers the ringing call. callId defaults to the id TDLib last reported. */
    fun acceptCall(callId: Int = _currentCallId.value) {
        if (callId == 0) return
        _lastError.value = null
        _isIncoming.value = false
        _callState.value = CallState.CONNECTING
        tdLib.acceptCall(callId)
    }

    /**
     * Rejects a ringing call without answering it. The state deliberately stays DECLINED so the
     * app-level handler can log it to the call history and cancel the notification; calling
     * reset() here made StateFlow conflate DECLINED straight into IDLE, so a decline was
     * silently dropped and the incoming-call notification never went away.
     */
    fun declineCall(callId: Int = _currentCallId.value) {
        if (callId != 0) tdLib.discardCall(callId, isDisconnected = false)
        // Only a live call may decline. A stale Decline tap from an old notification must not
        // fabricate a DECLINED history entry from IDLE.
        if (_callState.value.isLive()) {
            _callState.value = CallState.DECLINED
            _isIncoming.value = false
            stopTimer(preserveDuration = true)
        }
    }

    fun endCall() {
        val id = _currentCallId.value
        val wasLive = _callState.value.isLive()
        if (id != 0) tdLib.discardCall(id, isDisconnected = true, duration = _duration.value.toInt())
        _callState.value = CallState.ENDED
        _isIncoming.value = false
        stopTimer(preserveDuration = wasLive)
    }

    /**
     * Returns the call to IDLE so the chat regains the screen. TDLib will send no further update
     * once a call is discarded, so without this the UI stays stuck on a dead call.
     */
    fun reset() {
        stopTimer(preserveDuration = false)
        teardownMedia()
        _currentCallId.value = 0
        _isIncoming.value = false
        _lastError.value = null
        _readyInfo.value = null
        _callState.value = CallState.IDLE
    }

    /**
     * Phase 3: hands TDLib's ready material (key/servers/config) to the tgcalls engine and
     * puts Android audio routing into in-call mode. A missing engine (local build without the
     * CI-built libtgcallsjni.so) only means no media - the call itself must not break.
     */
    private fun startMediaEngine(ready: TdApi.CallStateReady) {
        val ctx = appContext ?: run {
            Log.w(TAG, "no context; media engine not started")
            return
        }
        val ok = TgCallsBridge.start(ctx, ready, isOutgoing = isOutgoingCall.get())
        if (ok) {
            CallAudioRouter.enterCall(ctx)
        } else {
            Log.w(TAG, "media engine unavailable (libtgcallsjni.so missing?) - signaling only")
        }
    }

    private fun teardownMedia() {
        TgCallsBridge.stop()
        CallAudioRouter.exitCall()
    }

    fun toggleMute() {
        _isMuted.value = !_isMuted.value
        tdLib.setMuted(_isMuted.value)
        TgCallsBridge.setMute(_isMuted.value)
    }

    fun toggleVideo() { _isVideoEnabled.value = !_isVideoEnabled.value }

    fun toggleSpeaker() {
        _isSpeaker.value = !_isSpeaker.value
        CallAudioRouter.setSpeaker(_isSpeaker.value)
    }

    fun switchCamera() {}

    fun release() { stopTimer(preserveDuration = false) }

    private fun startTimer() {
        timer?.cancel()
        val t = java.util.Timer("schatz-call-timer", true)
        timer = t
        t.scheduleAtFixedRate(object : java.util.TimerTask() { override fun run() { _duration.value += 1 } }, 1000, 1000)
    }

    /**
     * Stops the duration timer. preserveDuration keeps the recorded value long enough for the
     * history row to read it, which is how a hangup no longer logs as 0 seconds.
     */
    private fun stopTimer(preserveDuration: Boolean) {
        timer?.cancel()
        timer = null
        if (!preserveDuration) _duration.value = 0
    }
}
