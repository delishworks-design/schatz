package com.schatz.production.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import com.schatz.production.R
import com.schatz.production.managers.*

@Composable
fun SchatzApp(tdLib: TdLibUpdateManager, connectionManager: ConnectionManager, callManager: CallManager, securityManager: SecurityManager, voiceManager: VoiceMessageManager, callHistoryManager: CallHistoryManager, notificationManager: SchatzNotificationManager, fileManager: FileManager, chatManager: ChatManager, sharedVaultSyncManager: SharedVaultSyncManager, isDark: Boolean, onToggleDark:()->Unit) {
    var selected by remember { mutableStateOf(0) }
    val connectionState by connectionManager.state.collectAsState()
    val lastSeen by connectionManager.lastSeen.collectAsState()
    val callState by callManager.callState.collectAsState()
    val isInCall = callState != CallState.IDLE && callState != CallState.ENDED
    val partnerUser by connectionManager.partner.collectAsState()
    val privateChatState by connectionManager.privateChat.collectAsState()
    val partnerName = partnerUser?.firstName?.takeIf { it.isNotBlank() } ?: "Her"

    // Bind the shared vault to identity + private chat, then sync over TDLib
    LaunchedEffect(privateChatState) {
        val chat = privateChatState ?: return@LaunchedEffect
        if(connectionManager.myId != 0L) {
            sharedVaultSyncManager.init(connectionManager.myId, chat.id, connectionManager.partnerId)
        }
    }

    LaunchedEffect(callState) {
        if(callState == CallState.INCOMING || callState == CallState.RINGING) {
            notificationManager.showIncomingCallNotification("Her", callManager.isVideoEnabled.value, 0)
        } else if(callState == CallState.MISSED) {
            notificationManager.showMissedCallNotification("Her", callManager.isVideoEnabled.value)
            callHistoryManager.addFromCallState(callState, connectionManager.partnerId, "Her", if(callManager.isVideoEnabled.value) CallMedia.VIDEO else CallMedia.AUDIO, callManager.duration.value, false)
        } else if(callState == CallState.ENDED) {
            notificationManager.cancelIncomingCallNotification()
            callHistoryManager.addFromCallState(callState, connectionManager.partnerId, "Her", if(callManager.isVideoEnabled.value) CallMedia.VIDEO else CallMedia.AUDIO, callManager.duration.value, true)
        }
    }

    Scaffold(
        topBar = {
            if(!isInCall) {
                CenterAlignedTopAppBar(
                    title = {
                        Column(horizontalAlignment=Alignment.CenterHorizontally) {
                            Text("Schatz", style=MaterialTheme.typography.titleMedium)
                            Text(text=when(connectionState) {
                                ConnectionState.CONNECTED -> lastSeen
                                ConnectionState.CONNECTING -> "Connecting..."
                                ConnectionState.RECONNECTING -> "Reconnecting..."
                                ConnectionState.OFFLINE -> "Offline"
                                ConnectionState.AUTH_REQUIRED -> "Login required"
                                ConnectionState.ERROR -> "Connection error"
                            }, style=MaterialTheme.typography.labelSmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                        }
                    },
                    actions = {
                        val partner = connectionManager.partner.collectAsState().value
                        IconButton(onClick={ partner?.let { callManager.startCall(it.id, false) } }) { Icon(painterResource(R.drawable.ic_call_24), contentDescription="Call") }
                        IconButton(onClick={ partner?.let { callManager.startCall(it.id, true) } }) { Icon(painterResource(R.drawable.ic_video_call_24), contentDescription="Video call") }
                        IconButton(onClick={ selected = 3 }) { Icon(painterResource(R.drawable.ic_more_vert_24), contentDescription="Settings") }
                    }
                )
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when {
                isInCall -> CallScreen(callManager=callManager)
                selected==0 -> ChatScreen(tdLib=tdLib, connectionManager=connectionManager, voiceManager=voiceManager)
                selected==1 -> CallHistoryScreen(callHistoryManager=callHistoryManager, callManager=callManager, partnerId=connectionManager.partnerId)
                selected==2 -> VaultScreenWithSync(syncManager=sharedVaultSyncManager, myId=connectionManager.myId, partnerName=partnerName, onBackToChat={ selected = 0 })
                selected==3 -> SettingsScreen(securityManager=securityManager, isDark=isDark, onToggleDark=onToggleDark, onBackToChat={ selected = 0 }, onOpenCallHistory={ selected = 1 }, onOpenVault={ selected = 2 })
            }
        }
    }
}
