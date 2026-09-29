package com.schatz.production.managers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class CallService : Service() {
    companion object {
        const val CHANNEL_ID = "schatz_call_service"
        const val NOTIF_ID = 2001
        private const val TAG = "SchatzCallService"
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        // Promote to foreground here, not only in onStartCommand. startForegroundService() gives
        // the system a 5 second deadline from the moment the service is created, and it kills the
        // process with ForegroundServiceDidNotStartInTimeException if startForeground() has not
        // run by then. Doing the work in onCreate leaves onStartCommand a formality.
        startForegroundSafely()
    }

    private fun buildNotification(): android.app.Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Schatz call")
            .setContentText("Ongoing private call")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setOngoing(true)
            .build()

    /**
     * startForeground() throws when the OS refuses the requested type. Asking for microphone and
     * camera alongside phoneCall fails outright if RECORD_AUDIO or CAMERA has not been granted yet,
     * and the uncaught exception takes TDLib down mid-call - the crash the device reported as
     * ForegroundServiceDidNotStartInTimeException. Falling back to phoneCall alone keeps the
     * process (and the call) alive; the audio route is a separate concern from the service type.
     */
    private fun startForegroundSafely() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                startForeground(
                    NOTIF_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                )
                return
            } catch (t: Throwable) {
                Log.w(TAG, "full foreground type refused, falling back to phoneCall: $t")
            }
            try {
                startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
                return
            } catch (t: Throwable) {
                Log.e(TAG, "phoneCall foreground type also refused: $t")
            }
            try {
                // Last resort: no explicit type at all. Slower to gain the service's importance,
                // but a live TDLib beats a clean process exit.
                startForeground(NOTIF_ID, notification)
            } catch (t: Throwable) {
                Log.e(TAG, "untyped startForeground failed", t)
            }
        } else {
            try {
                startForeground(NOTIF_ID, notification)
            } catch (t: Throwable) {
                Log.e(TAG, "startForeground failed", t)
            }
        }
    }

    private fun createChannel() {
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Ongoing Call", android.app.NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Idempotent: onCreate already promoted us, and a refused promotion must not be fatal.
        startForegroundSafely()

        // Keep TDLib alive during call
        // Handle app minimized, backgrounded, screen locked
        //
        // NOT_STICKY: a sticky restart after the process dies would rebuild the "ongoing call"
        // notification with no call behind it, and the service has no way to tell. The caller
        // (MainActivity) restarts it whenever a call actually goes live.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App removed from recents - keep call alive or end gracefully
        super.onTaskRemoved(rootIntent)
    }
}
