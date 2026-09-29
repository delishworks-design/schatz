package com.schatz.production.voip

/**
 * Kotlin mirror of Telegram's org.telegram.messenger.voip.Instance data contract.
 *
 * The native glue (native/schatz_glue.cpp) reads these members by name through JNI
 * (JavaObject::getXField / GetMethodID on the nested classes), so field names, JVM
 * types, and constructor signatures are load-bearing - do not rename or retype them
 * without regenerating the glue.
 */
class Instance private constructor() {

    companion object {
        const val NET_TYPE_UNKNOWN = 0
        const val NET_TYPE_GPRS = 1
        const val NET_TYPE_EDGE = 2
        const val NET_TYPE_3G = 3
        const val NET_TYPE_HSPA = 4
        const val NET_TYPE_LTE = 5
        const val NET_TYPE_WIFI = 6
        const val NET_TYPE_ETHERNET = 7
        const val NET_TYPE_OTHER_HIGH_SPEED = 8
        const val NET_TYPE_OTHER_LOW_SPEED = 9
        const val NET_TYPE_DIALUP = 10
        const val NET_TYPE_OTHER_MOBILE = 11

        const val ENDPOINT_TYPE_INET = 0
        const val ENDPOINT_TYPE_LAN = 1
        const val ENDPOINT_TYPE_UDP_RELAY = 2
        const val ENDPOINT_TYPE_TCP_RELAY = 3

        const val STATE_WAIT_INIT = 1
        const val STATE_WAIT_INIT_ACK = 2
        const val STATE_ESTABLISHED = 3
        const val STATE_FAILED = 4
        const val STATE_RECONNECTING = 5

        const val DATA_SAVING_NEVER = 0
        const val DATA_SAVING_MOBILE = 1
        const val DATA_SAVING_ALWAYS = 2
        const val DATA_SAVING_ROAMING = 3

        const val AUDIO_STATE_MUTED = 0
        const val AUDIO_STATE_ACTIVE = 1

        const val VIDEO_STATE_INACTIVE = 0
        const val VIDEO_STATE_PAUSED = 1
        const val VIDEO_STATE_ACTIVE = 2

        const val PEER_CAP_GROUP_CALLS = 1
    }

    class Config @JvmOverloads constructor(
        @JvmField val initializationTimeout: Double,
        @JvmField val receiveTimeout: Double,
        @JvmField val dataSaving: Int,
        @JvmField val enableP2p: Boolean,
        @JvmField val enableAec: Boolean,
        @JvmField val enableNs: Boolean,
        @JvmField val enableAgc: Boolean,
        @JvmField val enableCallUpgrade: Boolean,
        @JvmField val enableSm: Boolean,
        @JvmField val logPath: String,
        @JvmField val statsLogPath: String,
        @JvmField val maxApiLayer: Int,
        @JvmField val customParameters: String,
    )

    class Endpoint(
        @JvmField val isRtc: Boolean,
        @JvmField val id: Long,
        @JvmField val ipv4: String,
        @JvmField val ipv6: String,
        @JvmField val port: Int,
        @JvmField val type: Int,
        @JvmField val peerTag: ByteArray?,
        @JvmField val turn: Boolean,
        @JvmField val stun: Boolean,
        @JvmField val username: String,
        @JvmField val password: String,
        @JvmField val tcp: Boolean,
        @JvmField var reflectorId: Int,
    )

    class Proxy(
        @JvmField val host: String,
        @JvmField val port: Int,
        @JvmField val login: String,
        @JvmField val password: String,
    )

    class EncryptionKey(
        @JvmField val value: ByteArray,
        @JvmField val isOutgoing: Boolean,
    )

    class FinalState(
        @JvmField val persistentState: ByteArray?,
        @JvmField val debugLog: String?,
        @JvmField val trafficStats: TrafficStats?,
        @JvmField val isRatingSuggested: Boolean,
    )

    class TrafficStats(
        @JvmField val bytesSentWifi: Long,
        @JvmField val bytesReceivedWifi: Long,
        @JvmField val bytesSentMobile: Long,
        @JvmField val bytesReceivedMobile: Long,
    )

    class Fingerprint(
        @JvmField val hash: String,
        @JvmField val setup: String,
        @JvmField val fingerprint: String,
    )

    /** Group-call only: read by the glue's RequestMediaChannelDescriptionTaskJava. */
    class RequestedParticipant(
        @JvmField var audioSsrc: Int = 0,
        @JvmField var userId: Long = 0L,
    )
}
