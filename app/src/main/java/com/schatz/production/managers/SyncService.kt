package com.schatz.production.managers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class SyncService : Service() {
    companion object {
        const val CHANNEL_ID = "schatz_sync_service"
        const val NOTIF_ID = 2002
        private const val TAG = "SchatzSyncService"
    }

    private var connectivityCallback: ConnectivityManager.NetworkCallback? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        registerConnectivityMonitor()
    }

    private fun createChannel() {
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Schatz Sync", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun registerConnectivityMonitor() {
        val cm = getSystemService(ConnectivityManager::class.java)
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Internet restored - reconnect TDLib, retry messages, resume uploads/downloads
                android.util.Log.d("SyncService", "Internet available - reconnecting TDLib")
                // In real app, notify TdLibUpdateManager to reconnect
            }

            override fun onLost(network: Network) {
                // Internet lost - set state to OFFLINE/RECONNECTING, pause transfers
                android.util.Log.d("SyncService", "Internet lost - pausing sync")
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                // Network changed - handle switch from WiFi to mobile etc
            }
        }

        cm.registerNetworkCallback(request, connectivityCallback!!)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // startForeground must be reached within ~5s of startForegroundService() or the system
        // kills the process. It also throws if the system refuses the type, and an uncaught throw
        // here happens at boot, where nobody is watching. Fall back instead of dying.
        startForegroundSafely()

        // NOT_STICKY, not STICKY: this service exists to watch connectivity so queued transfers
        // can resume. A sticky restart would re-run startForeground after every kill, turning a
        // refused promotion into a crash loop, and nothing here actually needs the restart -
        // BootReceiver starts it once and TDLib handles its own reconnection.
        return START_NOT_STICKY
    }

    private fun startForegroundSafely() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Schatz")
            .setContentText("Waiting for connection")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(false)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                return
            } catch (t: Throwable) {
                Log.w(TAG, "dataSync foreground type refused, falling back: $t")
            }
        }
        try {
            startForeground(NOTIF_ID, notification)
        } catch (t: Throwable) {
            Log.e(TAG, "startForeground failed", t)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        connectivityCallback?.let {
            val cm = getSystemService(ConnectivityManager::class.java)
            cm.unregisterNetworkCallback(it)
        }
        super.onDestroy()
    }
}
