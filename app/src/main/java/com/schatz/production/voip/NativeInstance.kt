package com.schatz.production.voip

import org.webrtc.VideoSink

/**
 * Kotlin mirror of Telegram's org.telegram.messenger.voip.NativeInstance JNI surface.
 *
 * Every `external` here maps 1:1 to an exported Java_* symbol in native/schatz_glue.cpp
 * (same names, package-renamed). Callback methods are invoked by the glue through
 * GetMethodID(NativeInstanceClass, "<name>", "<sig>") - names, parameter types and
 * static-vs-instance-ness are load-bearing.
 *
 * Callbacks arrive on tgcalls' internal threads; hop to main before touching UI.
 */
class NativeInstance {

    private var nativePtr: Long = 0L
    var persistentStateFilePath: String? = null
        internal set

    // ---- listeners (Kotlin side of the glue's GetMethodID callbacks) ----
    var onStateUpdatedCb: ((state: Int) -> Unit)? = null
    var onSignalBarsUpdatedCb: ((bars: Int) -> Unit)? = null
    var onSignalingDataCb: ((data: ByteArray) -> Unit)? = null
    var onRemoteMediaStateUpdatedCb: ((audioState: Int, videoState: Int) -> Unit)? = null
    var onNetworkStateUpdatedCb: ((connected: Boolean, inTransition: Boolean) -> Unit)? = null
    var onAudioLevelsUpdatedCb: ((uids: IntArray?, levels: FloatArray, voice: BooleanArray?) -> Unit)? = null
    var onParticipantDescriptionsRequiredCb: ((taskPtr: Long, ssrcs: IntArray) -> Unit)? = null
    var onEmitJoinPayloadCb: ((json: String, ssrc: Int) -> Unit)? = null
    var onRequestBroadcastPartCb: ((timestamp: Long, duration: Long, videoChannel: Int, quality: Int) -> Unit)? = null
    var onCancelRequestBroadcastPartCb: ((timestamp: Long, videoChannel: Int, quality: Int) -> Unit)? = null
    var onCancelRequestMediaChannelDescriptionCb: ((taskPtr: Long) -> Unit)? = null
    var onStopCb: ((state: Instance.FinalState) -> Unit)? = null
    var requestCurrentTimeCb: ((taskPtr: Long) -> Unit)? = null

    // ---- called from native ----
    private fun onStateUpdated(state: Int) {
        onStateUpdatedCb?.invoke(state)
    }

    private fun onSignalBarsUpdated(signalBars: Int) {
        onSignalBarsUpdatedCb?.invoke(signalBars)
    }

    private fun onSignalingData(data: ByteArray) {
        onSignalingDataCb?.invoke(data)
    }

    private fun onRemoteMediaStateUpdated(audioState: Int, videoState: Int) {
        onRemoteMediaStateUpdatedCb?.invoke(audioState, videoState)
    }

    private fun onNetworkStateUpdated(connected: Boolean, inTransition: Boolean) {
        onNetworkStateUpdatedCb?.invoke(connected, inTransition)
    }

    private fun onAudioLevelsUpdated(uids: IntArray?, levels: FloatArray, voice: BooleanArray?) {
        onAudioLevelsUpdatedCb?.invoke(uids, levels, voice)
    }

    private fun onParticipantDescriptionsRequired(taskPtr: Long, ssrcs: IntArray) {
        onParticipantDescriptionsRequiredCb?.invoke(taskPtr, ssrcs)
    }

    private fun onEmitJoinPayload(json: String, ssrc: Int) {
        onEmitJoinPayloadCb?.invoke(json, ssrc)
    }

    private fun onRequestBroadcastPart(timestamp: Long, duration: Long, videoChannel: Int, quality: Int) {
        onRequestBroadcastPartCb?.invoke(timestamp, duration, videoChannel, quality)
    }

    private fun onCancelRequestBroadcastPart(timestamp: Long, videoChannel: Int, quality: Int) {
        onCancelRequestBroadcastPartCb?.invoke(timestamp, videoChannel, quality)
    }

    private fun onCancelRequestMediaChannelDescription(taskPtr: Long) {
        onCancelRequestMediaChannelDescriptionCb?.invoke(taskPtr)
    }

    private fun onStop(state: Instance.FinalState) {
        onStopCb?.invoke(state)
    }

    private fun requestCurrentTime(taskPtr: Long) {
        requestCurrentTimeCb?.invoke(taskPtr)
    }

    // ---- instance externals ----
    external fun setGlobalServerConfig(serverConfigJson: String)
    external fun setNetworkType(networkType: Int)
    external fun setMuteMicrophone(muteMicrophone: Boolean)
    external fun onSignalingDataReceive(data: ByteArray)
    external fun getPersistentState(): ByteArray?
    external fun getLastError(): String?
    external fun getDebugInfo(): String?
    external fun getTrafficStats(): Instance.TrafficStats?
    external fun setBufferSize(size: Int)
    external fun setVolume(ssrc: Int, volume: Double)
    external fun setAudioOutputGainControlEnabled(enabled: Boolean)
    external fun setEchoCancellationStrength(strength: Int)
    external fun setVideoState(videoState: Int)
    external fun switchCamera(front: Boolean)
    external fun setupOutgoingVideo(localSink: VideoSink?, type: Int)
    external fun setupOutgoingVideoCreated(videoCapturer: Long)
    external fun hasVideoCapturer(): Boolean
    external fun onRequestTimeComplete(taskPtr: Long, time: Long)
    external fun setConferenceCallId(callId: Long)
    external fun setNoiseSuppressionEnabled(value: Boolean)
    external fun activateVideoCapturer(videoCapturer: Long)
    external fun clearVideoCapturer()
    external fun setVideoEndpointQuality(endpointId: String, quality: Int)
    external fun addIncomingVideoOutput(
        quality: Int,
        endpointId: String,
        ssrcGroups: Array<SsrcGroup>?,
        remoteSink: VideoSink?,
        userId: Long,
    ): Long

    external fun removeIncomingVideoOutput(nativeRemoteSink: Long)

    // group-only entry points (glue exports them; never used by Schatz's 1v1 flow)
    external fun setJoinResponsePayload(payload: String)
    external fun prepareForStream(isRtpStream: Boolean)
    external fun resetGroupInstance(set: Boolean, disconnect: Boolean)
    external fun onMediaDescriptionAvailable(taskPtr: Long, ssrcs: Array<Instance.RequestedParticipant>)
    external fun onStreamPartAvailable(
        ts: Long,
        buffer: java.nio.ByteBuffer,
        size: Int,
        timestamp: Long,
        videoChannel: Int,
        quality: Int,
    )

    private external fun stopNative()
    private external fun stopGroupNative()

    /** Stops the underlying tgcalls instance; safe to call more than once. */
    fun release() {
        if (nativePtr != 0L) {
            try {
                stopNative()
            } catch (t: Throwable) {
                // already gone
            }
        }
    }

    class SsrcGroup {
        @JvmField var semantics: String = ""
        @JvmField var ssrcs: IntArray = IntArray(0)
    }

    companion object {
        @JvmStatic
        private external fun makeNativeInstance(
            version: String,
            instance: NativeInstance,
            config: Instance.Config,
            persistentStateFilePath: String,
            endpoints: Array<Instance.Endpoint>,
            proxy: Instance.Proxy?,
            networkType: Int,
            encryptionKey: Instance.EncryptionKey,
            remoteSink: VideoSink?,
            videoCapturer: Long,
            aspectRatio: Float,
        ): Long

        @JvmStatic
        external fun getAllVersions(): Array<String>

        @JvmStatic
        external fun createVideoCapturer(localSink: VideoSink?, type: Int): Long

        @JvmStatic
        external fun setVideoStateCapturer(videoCapturer: Long, videoState: Int)

        @JvmStatic
        external fun switchCameraCapturer(videoCapturer: Long, front: Boolean)

        @JvmStatic
        external fun destroyVideoCapturer(videoCapturer: Long)

        @JvmStatic
        private external fun makeGroupNativeInstance(
            instance: NativeInstance,
            persistentStateFilePath: String,
            highQuality: Boolean,
            videoCapturer: Long,
            screencast: Boolean,
            noiseSupression: Boolean,
            conference: Boolean,
        ): Long

        /**
         * Creates the tgcalls instance. Mirrors Telegram's NativeInstance.make(): the
         * returned object must be kept alive for the whole call (the glue stores its
         * jobject as the platform-context peer).
         */
        fun make(
            version: String,
            config: Instance.Config,
            persistentStateFilePath: String,
            endpoints: Array<Instance.Endpoint>,
            proxy: Instance.Proxy?,
            networkType: Int,
            encryptionKey: Instance.EncryptionKey,
            remoteSink: VideoSink? = null,
            videoCapturer: Long = 0L,
            aspectRatio: Float = 1.0f,
        ): NativeInstance {
            val instance = NativeInstance()
            instance.persistentStateFilePath = persistentStateFilePath
            instance.nativePtr = makeNativeInstance(
                version, instance, config, persistentStateFilePath, endpoints,
                proxy, networkType, encryptionKey, remoteSink, videoCapturer, aspectRatio,
            )
            return instance
        }
    }
}
