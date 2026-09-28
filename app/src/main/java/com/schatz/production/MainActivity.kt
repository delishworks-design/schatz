package com.schatz.production

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import com.schatz.production.managers.*
import com.schatz.production.ui.SchatzApp
import com.schatz.production.ui.theme.SchatzTheme

class MainActivity : ComponentActivity() {
    private lateinit var tdLib: TdLibUpdateManager
    private lateinit var connectionManager: ConnectionManager
    private lateinit var vaultManager: VaultManager
    private lateinit var callManager: CallManager
    private lateinit var securityManager: SecurityManager
    private lateinit var voiceManager: VoiceMessageManager
    private lateinit var callHistoryManager: CallHistoryManager
    private lateinit var notificationManager: SchatzNotificationManager
    private lateinit var fileManager: FileManager
    private lateinit var chatManager: ChatManager
    private lateinit var sharedVaultSyncManager: SharedVaultSyncManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tdLib = TdLibUpdateManager(this)
        tdLib.init()
        connectionManager = ConnectionManager(tdLib)
        connectionManager.init()
        vaultManager = VaultManager(this)
        callManager = CallManager(tdLib)
        callManager.init()
        securityManager = SecurityManager(this)
        voiceManager = VoiceMessageManager(this)
        callHistoryManager = CallHistoryManager(this)
        notificationManager = SchatzNotificationManager(this)
        fileManager = FileManager(this, tdLib)
        chatManager = ChatManager(tdLib)
        sharedVaultSyncManager = SharedVaultSyncManager(this, tdLib, vaultManager)

        // Init shared vault sync when chat ready
        connectionManager.privateChat.let { chatFlow ->
            // Will init when chat available
        }

        setContent {
            var isDark by remember { mutableStateOf(false) }
            SchatzTheme(darkTheme = isDark) {
                SchatzApp(tdLib=tdLib, connectionManager=connectionManager, callManager=callManager, securityManager=securityManager, voiceManager=voiceManager, callHistoryManager=callHistoryManager, notificationManager=notificationManager, fileManager=fileManager, chatManager=chatManager, sharedVaultSyncManager=sharedVaultSyncManager, isDark=isDark, onToggleDark={isDark=!isDark})
            }
        }
    }

    override fun onDestroy() { tdLib.close(); voiceManager.cleanup(); super.onDestroy() }
}
