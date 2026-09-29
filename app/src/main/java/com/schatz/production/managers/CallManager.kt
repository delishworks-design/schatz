package com.schatz.production.managers

import android.content.Context
import android.util.Log
import com.schatz.production.voip.CallAudioRouter
import com.schatz.production.voip.TgCallsBridge
import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class CallState { IDLE, CALLING, CONNECTING, MEDIA_CONNECTING, CONNECTED, ENDED, INCOMING, RINGING, DECLINED, BUSY, FAILED, MISSED }

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

    /**
     * True once the media engine is actually up and carrying frames, as opposed to TDLib merely
     * having exchanged keys. TDLib reports CallStateReady long before tgcalls finishes its own
     * handshake, so treating Ready as "connected" showed a running call that was silent.
     */
    private val _isMediaActive = MutableStateFlow(false)
    val isMediaActive: StateFlow<Boolean> = _isMediaActive

    /** The peer's microphone state, as reported by tgcalls. Drives the "muted" hint. */
    private val _isRemoteMuted = MutableStateFlow(false)
    val isRemoteMuted: StateFlow<Boolean> = _isRemoteMuted

    /** tgcalls signal bars, 0-5. */
    private val _signalBars = MutableStateFlow(0)
    val signalBars: StateFlow<Int> = _signalBars

    /** False when the native engine could not be started at all (no .so in the build). */
    private val _isEngineAvailable = MutableStateFlow(false)
    val isEngineAvailable: StateFlow<Boolean> = _isEngineAvailable

    private var timer: java.util.Timer? = null
    /** Fires if tgcalls never reaches established, so the UI cannot be stuck on media connecting. */
    private var mediaFallbackTimer: java.util.Timer? = null
    /** The call id already answered, so a duplicate tap cannot send a second AcceptCall. */
    private var answeredCallId: Int = 0
    /**
     * States already acted on, for the call identified by [dedupeCallId]. TDLib repeats UpdateCall,
     * and re-running a branch re-fires its side effects, so repeats are dropped.
     */
    private val handledStates = java.util.LinkedHashSet<CallState>()

    /** The call the [handledStates] set belongs to; TDLib recycles ids, so it must be re-keyed. */
    private var dedupeCallId: Int = 0
    /** Set when a ringing call is answered, so the screen stops offering Answer/Decline. */
    private val _isAnswered = MutableStateFlow(false)
    val isAnswered: StateFlow<Boolean> = _isAnswered
    private val isOutgoingCall = java.util.concurrent.atomic.AtomicBoolean(false)

    fun init() {
        // Explicit label: this lambda is assigned to a property, so the implicit
        // return@onCallUpdate label does not exist.
        tdLib.onCallUpdate = callUpdate@{ call ->
            if (call.id != 0) _currentCallId.value = call.id
            if (call.userId != 0L) _peerId.value = call.userId
            // TDLib reports the video flag on the call itself. Trusting it keeps the notification,
            // the call screen and the history row from all disagreeing.
            _isVideoEnabled.value = call.isVideo

            // TDLib re-sends UpdateCall for the same call and state as the handshake progresses.
            // Re-applying a state we already applied re-fired the branch side effects (history
            // entries, teardown, engine restarts) and let a repeated CallStatePending flip CALLING
            // to RINGING, which is what made an outgoing call read as an incoming one. Nothing in
            // the when-block below is idempotent, so skip a state we already handled *for this
            // call id* - the id is part of the key because TDLib recycles small integers, and a
            // new call must not inherit the previous call's verdict.
            val incoming = when (val s = call.state) {
                is TdApi.CallStatePending -> if (call.isOutgoing) CallState.CALLING else CallState.RINGING
                is TdApi.CallStateExchangingKeys -> CallState.CONNECTING
                is TdApi.CallStateReady -> CallState.MEDIA_CONNECTING
                is TdApi.CallStateHangingUp -> CallState.ENDED
                is TdApi.CallStateDiscarded -> when (s.reason) {
                    is TdApi.CallDiscardReasonDeclined -> CallState.DECLINED
                    is TdApi.CallDiscardReasonMissed -> CallState.MISSED
                    is TdApi.CallDiscardReasonDisconnected -> CallState.FAILED
                    else -> CallState.ENDED
                }
                is TdApi.CallStateError -> CallState.FAILED
                else -> null
            }
            if (incoming != null) {
                // Every state transition is recorded before the dedupe check, so a call that dies
                // mid-handshake still shows the last state it actually reached. This trail is the
                // only evidence of how far a call got, since a native abort leaves no stack.
                CrashReporter.note("call id=${call.id} ${call.state.javaClass.simpleName} outgoing=${call.isOutgoing}")
                // A different call id than the one we have been tracking: start over.
                if (dedupeCallId != call.id) {
                    dedupeCallId = call.id
                    handledStates.clear()
                }
                if (!handledStates.add(incoming)) {
                    Log.d(TAG, "onCallUpdate: $incoming already handled for call ${call.id}, ignoring repeat")
                    return@callUpdate
                }
            }

            when (call.state) {
                // A pending call is CALLING for the caller and RINGING for the callee. TDLib sends
                // CallStatePending for both, so isOutgoing is the only way to tell them apart.
                // Either way this is a NEW call, so every per-call guard is cleared here. Leaving
                // answeredCallId set would make the next incoming call refuse its own Answer.
                is TdApi.CallStatePending -> {
                    answeredCallId = 0
                    _isAnswered.value = false
                    isOutgoingCall.set(call.isOutgoing)
                    _isIncoming.value = !call.isOutgoing
                    _callState.value = if (call.isOutgoing) CallState.CALLING else CallState.RINGING
                }

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
                    // Ready only means TDLib finished the key exchange. The media is not up yet,
                    // so the call enters MEDIA_CONNECTING and only becomes CONNECTED once the
                    // engine reports an established connection. Jumping straight to CONNECTED
                    // here is what made a silent call look like a live one.
                    CrashReporter.note("CallStateReady outgoing=${call.isOutgoing} servers=${ready.servers.size}")
                    _callState.value = CallState.MEDIA_CONNECTING
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
        // tgcalls reports from a native thread. Teardown calls back into the engine
        // (TgCallsBridge.stop -> stopNative), so doing it inline from that thread re-enters the
        // native teardown it is currently running and crashes/deadlocks. Everything terminal is
        // therefore posted to the main thread.
        tdLib.onCallError = { err ->
            val state = _callState.value
            if (state == CallState.CALLING || state == CallState.CONNECTING ||
                state == CallState.MEDIA_CONNECTING || state == CallState.RINGING) {
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
        // instead of a silent, forever-muted call. Invoked on a native thread, and teardownMedia
        // re-enters the engine's own stop, so it must never run inline here.
        TgCallsBridge.onError = { message ->
            CrashReporter.note("engine error: $message")
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                val state = _callState.value
                if (state.isLive()) {
                    Log.e(TAG, "media engine failed: $message")
                    _lastError.value = message
                    _callState.value = CallState.FAILED
                    stopTimer(preserveDuration = true)
                    teardownMedia()
                }
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
        _isAnswered.value = false
        // TDLib assigns the call id only after CreateCall is answered, so the previous call's id
        // must not be able to veto this one. -1 cannot match a real id, so the guard stays armed
        // but harmless until TDLib reports the new call.
        answeredCallId = -1
        isOutgoingCall.set(true)
        _callState.value = CallState.CALLING
        CrashReporter.note("startCall userId=$userId video=$isVideo")
        tdLib.createCall(userId, isVideo)
    }

    /**
     * Answers the ringing call. callId defaults to the id TDLib last reported.
     *
     * Guarded twice on purpose. One tap on the incoming notification fires TWO of these: the
     * shade action, then the Answer button on the call screen the full-screen intent opened. The
     * first call moved the state to CONNECTING before this function used to validate anything, so
     * the second one sailed through and TDLib answered it with "call not found" - which on this
     * TDLib build ends in a native abort, taking the call and the app with it. Requiring a
     * ringing state stops the duplicate, and the id backstop covers the case where the state
     * flaps back to RINGING before the first request is answered.
     */
    fun acceptCall(callId: Int = _currentCallId.value) {
        if (CallGuards.canAnswer(_currentCallId.value, callId, answeredCallId, _callState.value) != CallGuards.Decision.ALLOW) {
            Log.w(TAG, "acceptCall ignored: id=$callId current=${_currentCallId.value} state=${_callState.value} answered=$answeredCallId")
            return
        }
        CrashReporter.note("acceptCall id=$callId")
        answeredCallId = callId
        _isAnswered.value = true
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
     *
     * The liveness check runs BEFORE discardCall, not after: the old order sent the discard to
     * TDLib first, so a stale Decline tap from an old notification discarded a call the user had
     * already moved on from. Declining stays legal through the media handshake on purpose - if
     * tgcalls never establishes, this is the only way out.
     */
    fun declineCall(callId: Int = _currentCallId.value) {
        if (CallGuards.canDiscard(_currentCallId.value, callId, _callState.value) != CallGuards.Decision.ALLOW) {
            Log.w(TAG, "declineCall ignored: id=$callId current=${_currentCallId.value} state=${_callState.value}")
            return
        }
        if (_callState.value == CallState.INCOMING || _callState.value == CallState.RINGING) {
            answeredCallId = callId
        }
        tdLib.discardCall(callId, isDisconnected = false)
        _callState.value = CallState.DECLINED
        _isIncoming.value = false
        stopTimer(preserveDuration = true)
    }

    fun endCall() {
        val id = _currentCallId.value
        // Same rule as declineCall: nothing reaches TDLib for a call that is not live, and an ENDED
        // is only published for a real call. Publishing it unconditionally wrote a bogus history
        // row whenever a stale End tap landed while the app sat idle in the chat.
        if (CallGuards.canDiscard(_currentCallId.value, id, _callState.value) != CallGuards.Decision.ALLOW) {
            Log.w(TAG, "endCall ignored: id=$id current=${_currentCallId.value} state=${_callState.value}")
            return
        }
        tdLib.discardCall(id, isDisconnected = true, duration = _duration.value.toInt())
        _callState.value = CallState.ENDED
        _isIncoming.value = false
        stopTimer(preserveDuration = true)
    }

    /**
     * Returns the call to IDLE so the chat regains the screen. TDLib will send no further update
     * once a call is discarded, so without this the UI stays stuck on a dead call.
     */
    fun reset() {
        stopTimer(preserveDuration = false)
        teardownMedia()
        _currentCallId.value = 0
        answeredCallId = 0
        handledStates.clear()
        _isAnswered.value = false
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
            _isEngineAvailable.value = false
            // No engine and no fallback timer: fall back now or the call hangs on media connecting.
            _callState.value = CallState.CONNECTED
            if (timer == null) startTimer()
            return
        }

        // Wire the listener BEFORE starting the engine. tgcalls can report its first state from a
        // native thread the moment the instance is created, and a listener attached afterwards
        // misses that report - the call then sat on "Connecting media..." until the 30s fallback
        // even though media was up immediately.
        TgCallsBridge.onMediaStateChanged = { mediaState, remoteMuted, bars ->
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            handler.post {
                _isMediaActive.value = mediaState == com.schatz.production.voip.Instance.STATE_ESTABLISHED
                _isRemoteMuted.value = remoteMuted
                _signalBars.value = bars
                if (_isMediaActive.value && _callState.value == CallState.MEDIA_CONNECTING) {
                    _callState.value = CallState.CONNECTED
                    if (timer == null) startTimer()
                }
            }
        }

        val ok = TgCallsBridge.start(ctx, ready, isOutgoing = isOutgoingCall.get())
        _isEngineAvailable.value = ok
        if (!ok) {
            CrashReporter.note("media engine NOT started")
            Log.w(TAG, "media engine unavailable (libtgcallsjni.so missing?) - signaling only")
            TgCallsBridge.onMediaStateChanged = null
            // Without an engine there will be no media callback, so the call must not sit in
            // MEDIA_CONNECTING forever. Fall back to the signalling-only state.
            _callState.value = CallState.CONNECTED
            if (timer == null) startTimer()
            return
        }
        CallAudioRouter.enterCall(ctx)

        // start() may already have established before this line; seed from the bridge's own state
        // so a fast connection is not mistaken for a pending one.
        val current = TgCallsBridge.state.value
        if (current == com.schatz.production.voip.Instance.STATE_ESTABLISHED) {
            _isMediaActive.value = true
            if (_callState.value == CallState.MEDIA_CONNECTING) {
                _callState.value = CallState.CONNECTED
                if (timer == null) startTimer()
            }
        }

        // The engine can start and then never reach established (blackholed UDP, a peer that
        // never answers). Without this the call would sit on "Connecting media..." forever with
        // no way back, so fall back to the signalling-only state and let the banner say so.
        val fallback = java.util.Timer()
        mediaFallbackTimer = fallback
        fallback.schedule(object : java.util.TimerTask() {
            override fun run() {
                if (_callState.value == CallState.MEDIA_CONNECTING) {
                    Log.w(TAG, "media did not establish in time; falling back to signalling-only")
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        if (_callState.value == CallState.MEDIA_CONNECTING) {
                            _callState.value = CallState.CONNECTED
                            if (timer == null) startTimer()
                        }
                    }
                }
            }
        }, 30_000L)
    }

    private fun teardownMedia() {
        mediaFallbackTimer?.cancel()
        mediaFallbackTimer = null
        TgCallsBridge.onMediaStateChanged = null
        TgCallsBridge.stop()
        CallAudioRouter.exitCall()
        _isMediaActive.value = false
        _isRemoteMuted.value = false
        _signalBars.value = 0
        _isEngineAvailable.value = false
    }

    fun toggleMute() {
        if (!_callState.value.isLive()) {
            Log.w(TAG, "toggleMute ignored: no live call (${_callState.value})")
            return
        }
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

    /**
     * The activity is going away. Stopping only the call timer left the native engine running and
     * the audio route pinned in MODE_IN_COMMUNICATION, so the microphone stayed held and the
     * recorder never got released - which is also what makes the next call fail to open audio.
     */
    fun release() {
        stopTimer(preserveDuration = false)
        mediaFallbackTimer?.cancel()
        mediaFallbackTimer = null
        if (_callState.value.isLive()) {
            teardownMedia()
        }
        TgCallsBridge.onMediaStateChanged = null
    }

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
