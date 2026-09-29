package com.schatz.production.voip

import android.content.Context
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import com.schatz.production.managers.CallManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.drinkless.tdlib.TdApi
import org.json.JSONObject
import org.telegram.messenger.ApplicationLoader
import org.webrtc.ContextUtils
import java.io.File

/**
 * Facade over the tgcalls native engine (libtgcallsjni.so, built in CI from Telegram
 * Android's voip stack - see native/README.md).
 *
 * Flow: CallManager sees TdApi.CallStateReady -> start() builds the tgcalls instance
 * (key/servers/config straight from TDLib) -> signaling bytes flow both ways through
 * onSignalingOut / sendSignaling() -> TDLib's SendCallSignalingData relay.
 *
 * Everything degrades gracefully when the .so is missing (e.g. a local build without
 * the CI artifact): start() returns false and calls stay as they were before Phase 3 -
 * connected signaling, no media.
 */
object TgCallsBridge {

    private const val TAG = "TgCallsBridge"

    /** Must match callProtocol().libraryVersions[0] (TdLibUpdateManager). */
    const val DEFAULT_VERSION = "13.0.0"

    private val _loaded = MutableStateFlow(false)
    val loaded: StateFlow<Boolean> = _loaded.asStateFlow()

    /** tgcalls connection state: 1 WaitInit, 2 WaitInitAck, 3 Established, 4 Failed, 5 Reconnecting. */
    private val _state = MutableStateFlow(0)
    val state: StateFlow<Int> = _state.asStateFlow()

    /** (remote audio state, remote video state) - Instance.AUDIO_STATE_* / VIDEO_STATE_*. */
    private val _remoteMedia = MutableStateFlow(
        Instance.AUDIO_STATE_ACTIVE to Instance.VIDEO_STATE_INACTIVE,
    )
    val remoteMedia: StateFlow<Pair<Int, Int>> = _remoteMedia.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    /** tgcalls -> TDLib: bytes to hand to SendCallSignalingData (set by CallManager). */
    var onSignalingOut: ((data: ByteArray) -> Unit)? = null

    /** Fired when tgcalls reports STATE_FAILED (media path died even if signaling lives). */
    var onError: ((message: String) -> Unit)? = null

    private var instance: NativeInstance? = null
    private val lock = Any()

    fun isEngineAvailable(): Boolean = _loaded.value

    /** Loads the native engine once. Returns false (never throws) when unavailable. */
    fun init(context: Context): Boolean {
        synchronized(lock) {
            if (_loaded.value) return true
            return try {
                val app = context.applicationContext
                ApplicationLoader.applicationContext = app
                ContextUtils.initialize(app)
                System.loadLibrary("tgcallsjni")
                val versions = try {
                    NativeInstance.getAllVersions().joinToString()
                } catch (t: Throwable) {
                    "unknown (${t.javaClass.simpleName})"
                }
                _loaded.value = true
                Log.i(TAG, "tgcalls loaded, versions: $versions")
                true
            } catch (t: Throwable) {
                Log.e(TAG, "tgcalls unavailable: $t")
                _loaded.value = false
                false
            }
        }
    }

    /**
     * Builds and starts the tgcalls instance for a TDLib-ready call.
     * Returns false when the engine is unavailable or the handshake material is bad.
     */
    fun start(context: Context, ready: TdApi.CallStateReady, isOutgoing: Boolean): Boolean {
        synchronized(lock) {
            if (!init(context)) return false
            stopLocked()

            val key = ready.encryptionKey
            if (key == null || key.size < 256) {
                Log.e(TAG, "encryption key too short: ${key?.size ?: -1}")
                _lastError.value = "invalid encryption key"
                return false
            }

            val app = context.applicationContext
            val version = ready.protocol?.libraryVersions?.firstOrNull() ?: DEFAULT_VERSION
            val config = buildConfig(app, ready)
            val endpoints = buildEndpoints(ready.servers)
            val stateFile = File(app.cacheDir, "voip_persistent_state.json").absolutePath

            val netType = currentNetworkType(app)
            val created = try {
                NativeInstance.make(
                    version = version,
                    config = config,
                    persistentStateFilePath = stateFile,
                    endpoints = endpoints,
                    proxy = null,
                    networkType = netType,
                    encryptionKey = Instance.EncryptionKey(key, isOutgoing),
                    remoteSink = null,
                    videoCapturer = 0L,
                    aspectRatio = 1.0f,
                )
            } catch (t: Throwable) {
                Log.e(TAG, "makeNativeInstance failed", t)
                _lastError.value = t.message ?: "engine start failed"
                return false
            }

            bind(created)
            instance = created

            // Mirrors Telegram's Instance.makeInstance(): server config + defaults.
            try {
                created.setGlobalServerConfig("{}")
            } catch (t: Throwable) {
                Log.w(TAG, "setGlobalServerConfig: $t")
            }

            _state.value = Instance.STATE_WAIT_INIT
            _lastError.value = null
            Log.i(
                TAG,
                "tgcalls started version=$version outgoing=$isOutgoing " +
                    "servers=${endpoints.size} netType=$netType",
            )
            return true
        }
    }

    /** Inbound leg: TDLib UpdateNewCallSignalingData bytes -> tgcalls. */
    fun sendSignaling(data: ByteArray) {
        val inst = instance ?: run {
            Log.w(TAG, "signaling dropped: no instance")
            return
        }
        try {
            inst.onSignalingDataReceive(data)
        } catch (t: Throwable) {
            Log.e(TAG, "onSignalingDataReceive failed", t)
        }
    }

    fun setMute(muted: Boolean) {
        try {
            instance?.setMuteMicrophone(muted)
        } catch (t: Throwable) {
            Log.e(TAG, "setMuteMicrophone failed", t)
        }
    }

    fun setNetworkType(context: Context, networkType: Int) {
        try {
            instance?.setNetworkType(networkType)
        } catch (t: Throwable) {
            Log.w(TAG, "setNetworkType failed", t)
        }
    }

    /** Tears down the engine (hangup / discard / error). Safe when nothing is running. */
    fun stop() {
        synchronized(lock) { stopLocked() }
    }

    private fun stopLocked() {
        val inst = instance ?: return
        instance = null
        try {
            inst.release()
        } catch (t: Throwable) {
            Log.w(TAG, "release failed: $t")
        }
        _state.value = 0
        _remoteMedia.value = Instance.AUDIO_STATE_ACTIVE to Instance.VIDEO_STATE_INACTIVE
    }

    private fun bind(created: NativeInstance) {
        created.onStateUpdatedCb = { s ->
            _state.value = s
            if (s == Instance.STATE_FAILED) {
                val err = try {
                    created.getLastError()
                } catch (t: Throwable) {
                    null
                }
                val message = err ?: "media connection failed"
                _lastError.value = message
                onError?.invoke(message)
            }
        }
        created.onSignalingDataCb = { data ->
            val out = onSignalingOut
            if (out != null) {
                out(data)
            } else {
                Log.w(TAG, "no onSignalingOut handler; dropping ${data.size} bytes")
            }
        }
        created.onRemoteMediaStateUpdatedCb = { audio, video ->
            _remoteMedia.value = audio to video
        }
        created.onSignalBarsUpdatedCb = { /* UI hook, Phase 3 UI */ }
        created.onNetworkStateUpdatedCb = { connected, _ ->
            Log.d(TAG, "network connected=$connected")
        }
        created.onAudioLevelsUpdatedCb = { _, _, _ -> /* UI hook */ }
        created.requestCurrentTimeCb = { taskPtr ->
            try {
                created.onRequestTimeComplete(taskPtr, System.currentTimeMillis())
            } catch (t: Throwable) {
                Log.w(TAG, "onRequestTimeComplete failed", t)
            }
        }
        created.onStopCb = { finalState ->
            Log.i(
                TAG,
                "engine stopped state=${finalState?.isRatingSuggested ?: false}",
            )
            synchronized(lock) {
                if (instance === created) instance = null
            }
        }
        // Group-call callbacks: never invoked in Schatz's 1v1 flow, but the glue may
        // look them up - keep them harmless.
        created.onParticipantDescriptionsRequiredCb = { _, _ -> }
        created.onEmitJoinPayloadCb = { _, _ -> }
        created.onRequestBroadcastPartCb = { _, _, _, _ -> }
        created.onCancelRequestBroadcastPartCb = { _, _, _ -> }
        created.onCancelRequestMediaChannelDescriptionCb = { _ -> }
    }

    private fun buildConfig(context: Context, ready: TdApi.CallStateReady): Instance.Config {
        val json = try {
            JSONObject(ready.config ?: "")
        } catch (t: Throwable) {
            JSONObject()
        }

        // Server-provided timeouts (api/calls config JSON), with conservative fallbacks.
        val initTimeout = json.optDouble("initialization_timeout", 10.0)
        val recvTimeout = json.optDouble("receive_timeout", 15.0)
        var dataSaving = json.optInt("data_saving", Instance.DATA_SAVING_NEVER)
        if (dataSaving == Instance.DATA_SAVING_ROAMING) {
            // We do not track roaming state; never silently cut connectivity (Telegram
            // maps roaming down to NEVER/MOBILE based on the radio).
            dataSaving = Instance.DATA_SAVING_NEVER
        }

        // Mirror VoIPService: when the system provides AEC/NS the engine defers to it.
        val sysAec = try {
            AcousticEchoCanceler.isAvailable()
        } catch (t: Throwable) {
            false
        }
        val sysNs = try {
            NoiseSuppressor.isAvailable()
        } catch (t: Throwable) {
            false
        }

        val logDir = context.cacheDir
        return Instance.Config(
            initializationTimeout = initTimeout,
            receiveTimeout = recvTimeout,
            dataSaving = dataSaving,
            enableP2p = ready.allowP2p,
            enableAec = !sysAec,
            enableNs = !sysNs,
            enableAgc = true,
            enableCallUpgrade = false,
            enableSm = false,
            logPath = File(logDir, "schatz_tgcalls.log").absolutePath,
            statsLogPath = File(logDir, "schatz_tgcalls_stats.log").absolutePath,
            maxApiLayer = ready.protocol?.maxLayer ?: 92,
            customParameters = ready.customParameters ?: "",
        )
    }

    private fun buildEndpoints(servers: Array<TdApi.CallServer>?): Array<Instance.Endpoint> {
        val list = servers ?: return emptyArray()

        // Mirrors VoIPService's reflectorId assignment: 1-based rank among the sorted
        // non-WebRTC connection ids, 0 for everything else.
        val reflectorIds = list
            .filter { it.type !is TdApi.CallServerTypeWebrtc }
            .map { it.id }
            .sorted()
        val reflectorMap = reflectorIds.mapIndexed { index, id -> id to (index + 1) }.toMap()

        return list.map { server ->
            val webrtc = server.type as? TdApi.CallServerTypeWebrtc
            val reflector = server.type as? TdApi.CallServerTypeTelegramReflector
            Instance.Endpoint(
                isRtc = webrtc != null,
                id = server.id,
                ipv4 = server.ipAddress ?: "",
                ipv6 = server.ipv6Address ?: "",
                port = server.port,
                type = Instance.ENDPOINT_TYPE_UDP_RELAY,
                peerTag = reflector?.peerTag,
                turn = webrtc?.supportsTurn ?: false,
                stun = webrtc?.supportsStun ?: false,
                username = webrtc?.username ?: "",
                password = webrtc?.password ?: "",
                tcp = reflector?.isTcp ?: false,
                reflectorId = reflectorMap[server.id] ?: 0,
            )
        }.toTypedArray()
    }

    private fun currentNetworkType(context: Context): Int {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return Instance.NET_TYPE_UNKNOWN
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Instance.NET_TYPE_WIFI
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Instance.NET_TYPE_ETHERNET
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        // Fine-grained radio class needs TelephonyManager; LTE is the
                        // overwhelmingly common case and only affects bitrate hints.
                        Instance.NET_TYPE_LTE
                    } else {
                        Instance.NET_TYPE_3G
                    }
                }
                else -> Instance.NET_TYPE_OTHER_HIGH_SPEED
            }
        } catch (t: Throwable) {
            Instance.NET_TYPE_UNKNOWN
        }
    }

    /** For CallManager diagnostics. */
    fun engineVersions(): Array<String> = if (_loaded.value) {
        try {
            NativeInstance.getAllVersions()
        } catch (t: Throwable) {
            emptyArray()
        }
    } else {
        emptyArray()
    }

    /** Exposed for CallManager so a FAILED engine state can surface as the call error. */
    fun consumeError(): String? {
        val err = _lastError.value
        _lastError.value = null
        return err
    }
}
