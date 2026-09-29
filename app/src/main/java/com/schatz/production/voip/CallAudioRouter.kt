package com.schatz.production.voip

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.util.Log

/**
 * Android-side audio routing for calls (P3-6).
 *
 * tgcalls/webrtc opens the capture/playback streams; WHERE playback goes (earpiece,
 * speaker, Bluetooth SCO) is owned by AudioManager. Route changes only take effect
 * while mode is MODE_IN_COMMUNICATION, hence enterCall()/exitCall().
 */
object CallAudioRouter {

    private const val TAG = "CallAudioRouter"

    private var audioManager: AudioManager? = null
    private var inCall = false
    private var speakerOn = false
    private var scoActive = false

    fun enterCall(context: Context) {
        val am = context.applicationContext
            .getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager = am
        inCall = true
        speakerOn = false
        scoActive = false
        try {
            am.mode = AudioManager.MODE_IN_COMMUNICATION
            am.isSpeakerphoneOn = false
        } catch (t: Throwable) {
            Log.e(TAG, "enterCall routing failed", t)
        }
        Log.i(TAG, "enterCall mode=IN_COMMUNICATION speaker=off")
    }

    fun exitCall() {
        val am = audioManager ?: return
        inCall = false
        try {
            if (scoActive) {
                am.stopBluetoothSco()
                am.isBluetoothScoOn = false
                scoActive = false
            }
            am.isSpeakerphoneOn = false
            am.mode = AudioManager.MODE_NORMAL
        } catch (t: Throwable) {
            Log.e(TAG, "exitCall routing failed", t)
        }
        Log.i(TAG, "exitCall mode=NORMAL")
    }

    /** Earpiece <-> loudspeaker. No-op before enterCall(). */
    fun setSpeaker(on: Boolean) {
        val am = audioManager ?: return
        if (!inCall) return
        try {
            if (on && scoActive) {
                am.stopBluetoothSco()
                am.isBluetoothScoOn = false
                scoActive = false
            }
            am.isSpeakerphoneOn = on
            speakerOn = on
            Log.i(TAG, "setSpeaker $on")
        } catch (t: Throwable) {
            Log.e(TAG, "setSpeaker failed", t)
        }
    }

    val isSpeakerOn: Boolean get() = speakerOn

    fun isBluetoothAvailable(context: Context): Boolean {
        val am = context.applicationContext
            .getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        if (!am.isBluetoothScoAvailableOffCall) return false
        return try {
            am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any {
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
            }
        } catch (t: Throwable) {
            false
        }
    }

    /** Toggles the Bluetooth SCO link (only while in call). */
    fun setBluetooth(on: Boolean) {
        val am = audioManager ?: return
        if (!inCall) return
        try {
            if (on) {
                am.startBluetoothSco()
                am.isBluetoothScoOn = true
                am.isSpeakerphoneOn = false
                speakerOn = false
                scoActive = true
            } else {
                am.stopBluetoothSco()
                am.isBluetoothScoOn = false
                scoActive = false
            }
            Log.i(TAG, "setBluetooth $on")
        } catch (t: Throwable) {
            Log.e(TAG, "setBluetooth failed", t)
        }
    }

    val isScoActive: Boolean get() = scoActive
}
