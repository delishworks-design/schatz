package com.schatz.production.managers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.schatz.production.MainActivity
import com.schatz.production.R

class SchatzNotificationManager(private val context: Context) {
    companion object {
        const val CHANNEL_MESSAGES = "schatz_messages"
        const val CHANNEL_CALLS = "schatz_calls"
        const val CHANNEL_FILES = "schatz_files"
        const val NOTIF_ID_MESSAGE = 1001
        const val NOTIF_ID_INCOMING_CALL = 1002
        const val NOTIF_ID_MISSED_CALL = 1003
        const val NOTIF_ID_FILE = 1004
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createChannels()
    }

    private fun createChannels() {
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val messageChannel = NotificationChannel(
                CHANNEL_MESSAGES,
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "New messages from Her"
                enableVibration(true)
                setShowBadge(true)
            }

            val callChannel = NotificationChannel(
                CHANNEL_CALLS,
                "Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Incoming and missed calls"
                enableVibration(true)
                setShowBadge(true)
            }

            val fileChannel = NotificationChannel(
                CHANNEL_FILES,
                "Files",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "File transfers"
                enableVibration(false)
            }

            notificationManager.createNotificationChannels(listOf(messageChannel, callChannel, fileChannel))
        }
    }

    fun showNewMessageNotification(senderName: String, messageText: String, chatId: Long, hidePreview: Boolean = false) {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("open_chat_id", chatId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(context, CHANNEL_MESSAGES)
            .setSmallIcon(android.R.drawable.ic_dialog_email) // Replace with app icon
            .setContentTitle(senderName)
            .setContentText(if(hidePreview) "New message" else messageText)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .addAction(android.R.drawable.ic_menu_send, "Reply", pendingIntent)
            .addAction(android.R.drawable.ic_menu_view, "Mark as read", pendingIntent)
            .build()

        notificationManager.notify(NOTIF_ID_MESSAGE, notification)
    }

    fun showIncomingCallNotification(callerName: String, isVideo: Boolean, callId: Int) {
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("incoming_call_id", callId)
            putExtra("is_video", isVideo)
        }
        val fullScreenPending = PendingIntent.getActivity(context, 1, fullScreenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val answerIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("answer_call_id", callId)
        }
        val answerPending = PendingIntent.getActivity(context, 2, answerIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val declineIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("decline_call_id", callId)
        }
        val declinePending = PendingIntent.getActivity(context, 3, declineIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(context, CHANNEL_CALLS)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle(if(isVideo) "Incoming video call" else "Incoming call")
            .setContentText(callerName)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPending, true)
            .setAutoCancel(false)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_call, "Answer", answerPending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declinePending)
            .build()

        notificationManager.notify(NOTIF_ID_INCOMING_CALL, notification)
    }

    fun showMissedCallNotification(callerName: String, isVideo: Boolean) {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("open_calls", true)
        }
        val pendingIntent = PendingIntent.getActivity(context, 4, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(context, CHANNEL_CALLS)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Missed ${if(isVideo) "video" else "voice"} call")
            .setContentText(callerName)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(NOTIF_ID_MISSED_CALL, notification)
    }

    fun showFileEventNotification(fileName: String, isUpload: Boolean) {
        val notification = NotificationCompat.Builder(context, CHANNEL_FILES)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(if(isUpload) "Upload complete" else "Download complete")
            .setContentText(fileName)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(NOTIF_ID_FILE, notification)
    }

    fun cancelIncomingCallNotification() {
        notificationManager.cancel(NOTIF_ID_INCOMING_CALL)
    }

    fun cancelAll() {
        notificationManager.cancelAll()
    }
}
