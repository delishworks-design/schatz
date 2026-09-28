package com.schatz.production.managers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class SyncService : Service() {
    companion object {
        const val CHANNEL_ID = "schatz_sync_service"
        const val NOTIF_ID = 2002
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
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Schatz")
            .setContentText("Syncing messages")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(false)
            .build()

        startForeground(NOTIF_ID, notification)

        // Handle:
        // - App backgrounded
        // - Screen locked
        // - Device reconnects
        // - TDLib session survival

        return START_STICKY
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
