package com.schatz.production.managers

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log

/**
 * Plays the loop of an incoming call: a looping ringtone plus a repeating vibration pattern.
 *
 * Nothing in the app produced any sound or haptic before this, so a call that arrived while the
 * phone was on the table was completely silent unless the notification happened to show. Both
 * channels are driven from the call state (start on INCOMING/RINGING, stop on everything else)
 * so they can never outlive the call.
 */
class CallRinger(context: Context) {
    companion object { const val TAG = "SchatzRinger" }

    private val appContext = context.applicationContext
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    // Guards against a stop() that races a start() still preparing the player.
    @Volatile private var active = false

    fun start() {
        if (active) return
        active = true
        startRingtone()
        startVibration()
    }

    fun stop() {
        active = false
        val p = player
        player = null
        if (p != null) {
            try { p.stop() } catch (_: IllegalStateException) { /* never prepared */ }
            try { p.release() } catch (_: Throwable) { /* already released */ }
        }
        val v = vibrator
        vibrator = null
        try { v?.cancel() } catch (_: Throwable) { /* service gone */ }
    }

    private fun startRingtone() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE) ?: return
            val mp = MediaPlayer()
            mp.setDataSource(appContext, uri)
            // USAGE_NOTIFICATION_RINGTONE routes to the ring stream, so the phone's silent /
            // vibrate profile is respected instead of blasting over it.
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            mp.isLooping = true
            mp.setOnPreparedListener { prepared ->
                if (active && player === prepared) {
                    try { prepared.start() } catch (_: IllegalStateException) { stop() }
                } else {
                    // The call was answered or declined while the file was still decoding.
                    try { prepared.release() } catch (_: Throwable) { }
                }
            }
            mp.setOnErrorListener { failed, _, _ ->
                if (player === failed) {
                    player = null
                    try { failed.release() } catch (_: Throwable) { }
                }
                true
            }
            player = mp
            // prepare() on the main thread can jank the UI on a slow storage read; prepareAsync
            // keeps the incoming-call screen responsive.
            mp.prepareAsync()
        } catch (t: Throwable) {
            Log.e(TAG, "ringtone start failed", t)
        }
    }

    private fun startVibration() {
        try {
            val v = appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (!v.hasVibrator()) return
            // on, pause, on, pause ... repeated from index 0 so it loops with the ringtone.
            val pattern = longArrayOf(0, 500, 700, 500)
            val amplitudes = intArrayOf(0, 255, 0, 255)
            v.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, 0))
            vibrator = v
        } catch (t: Throwable) {
            Log.e(TAG, "vibration start failed", t)
        }
    }
}
