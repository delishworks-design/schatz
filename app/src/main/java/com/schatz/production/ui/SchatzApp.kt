package com.schatz.production.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import com.schatz.production.R
import com.schatz.production.managers.*
import kotlinx.coroutines.delay
import org.drinkless.tdlib.TdApi

/** Destination ids for the single-screen navigator. */
object Nav {
    const val CHAT = 0
    const val CALLS = 1
    const val VAULT = 2
    const val SETTINGS = 3
    const val SET_PIN = 4
}

private fun awaitingAuth(state: TdApi.AuthorizationState?): Boolean = when (state) {
    is TdApi.AuthorizationStateWaitPhoneNumber,
    is TdApi.AuthorizationStateWaitCode,
    is TdApi.AuthorizationStateWaitPassword -> true
    else -> false
}

@Composable
private fun WaitingScreen() {
    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
    }
}

@Composable
fun SchatzApp(
    tdLib: TdLibUpdateManager,
    connectionManager: ConnectionManager,
    callManager: CallManager,
    securityManager: SecurityManager,
    voiceManager: VoiceMessageManager,
    callHistoryManager: CallHistoryManager,
    notificationManager: SchatzNotificationManager,
    fileManager: FileManager,
    chatManager: ChatManager,
    sharedVaultSyncManager: SharedVaultSyncManager,
    enhancedVaultManager: EnhancedVaultManager,
    autoLockManager: AutoLockManager,
    callEnhancedManager: CallEnhancedManager,
    isDark: Boolean,
    onToggleDark: () -> Unit,
    // Bumped by MainActivity when the missed-call notification is tapped; each new tap is a new
    // value so the navigation effect refires even when the user is already somewhere else.
    openCallsTick: Int = 0
) {
    var selected by remember { mutableStateOf(Nav.CHAT) }
    val authState by tdLib.authState.collectAsState()
    val isLocked by autoLockManager.isLocked.collectAsState()
    val myId by connectionManager.myId.collectAsState()
    val partnerId by connectionManager.partnerId.collectAsState()
    val connectionState by connectionManager.state.collectAsState()
    val lastSeen by connectionManager.lastSeen.collectAsState()
    val privateChatState by connectionManager.privateChat.collectAsState()
    val partnerUser by connectionManager.partner.collectAsState()

    // 1. Auth gate. Shown only for the three states that actually need user input, so the
    //    first WaitTdlibParameters tick does not flash the login screen.
    if (awaitingAuth(authState)) {
        AuthScreen(tdLib)
        return
    }

    // 2. Waiting / torn-down states: no input required, just hold on the spinner.
    if (authState != null && authState !is TdApi.AuthorizationStateReady) {
        WaitingScreen()
        return
    }

    // 3. PIN gate, only once we are actually authenticated.
    if (isLocked) {
        PinScreen(securityManager, autoLockManager) { /* autoLockManager already cleared the flag */ }
        return
    }

    // 4. Pairing gate. Gated on being authorized (not on myId != 0): getMe needs a live TDLib,
    //    and a fresh install once sat on "Connecting..." forever because the screen it unlocks
    //    was itself waiting on the very request that had failed. An authorized-but-unpaired
    //    account must always be able to reach the screen that fixes it.
    if (authState is TdApi.AuthorizationStateReady && partnerId == 0L) {
        PairPartnerScreen(connectionManager) { connectionManager.retry() }
        return
    }

    // Asked only once the user is actually signed in and paired.
    RequestRuntimePermissions()
    val callState by callManager.callState.collectAsState()
    // A call is "live" for any state that is neither idle nor a terminal one. Testing only
    // `!= IDLE && != ENDED` left the user trapped on the call screen after a declined, missed or
    // failed call, because those states are neither of the two.
    val isInCall = callState.isLive()
    // FAILED is terminal, so isInCall drops it - but the user has to SEE the failure (and the
    // real TDLib reason) before it is cleared, so the call screen owns the surface for FAILED too.
    val callOwnsScreen = isInCall || callState == CallState.FAILED
    val currentCallId by callManager.currentCallId.collectAsState()
    val partnerName = partnerUser?.firstName?.takeIf { it.isNotBlank() }
        ?: partnerUser?.usernames?.activeUsernames?.firstOrNull()?.removePrefix("@")
        ?: "Partner"

    // The chat top bar belongs to the chat surface only. Every other destination renders its own
    // header, so showing it there produced a doubled header.
    val showTopBar = !callOwnsScreen && (selected == Nav.CHAT || selected == Nav.CALLS)

    // System back: leave the sub-screens and return to chat.
    BackHandler(enabled = !callOwnsScreen && selected != Nav.CHAT) { selected = Nav.CHAT }

    // Missed-call notification tap: open the call history.
    LaunchedEffect(openCallsTick) { if (openCallsTick > 0) selected = Nav.CALLS }

    // Incoming-call ringtone + vibration, driven purely by the call state.
    val context = LocalContext.current
    val ringer = remember { CallRinger(context) }
    LaunchedEffect(callState) {
        if (callState == CallState.INCOMING || callState == CallState.RINGING) ringer.start()
        else ringer.stop()
    }
    DisposableEffect(Unit) { onDispose { ringer.stop() } }

    // Bind the shared vault to identity + private chat, then sync over TDLib
    LaunchedEffect(privateChatState, myId, partnerId) {
        val chat = privateChatState ?: return@LaunchedEffect
        if (myId != 0L && partnerId != 0L) {
            sharedVaultSyncManager.init(myId, chat.id, partnerId)
        }
    }

    // TDLib sends no further update once a call is discarded, so a terminal state has to be
    // consumed here or the user stays on a dead call screen.
    LaunchedEffect(callState) {
        val media = if (callManager.isVideoEnabled.value) CallMedia.VIDEO else CallMedia.AUDIO
        // Direction has to come from the live call, not from the state being logged. These
        // branches used to hardcode isFromMe (false for missed/declined/failed, true for ended),
        // which is what made history rows read as the wrong direction - an outgoing call that
        // failed showed up as incoming. A decline is only ever the local user hanging up, so it
        // is the one case that is always ours.
        val outgoing = callManager.isIncoming.value.not()
        when (callState) {
            CallState.INCOMING, CallState.RINGING ->
                // currentCallId used to be hardcoded 0, so the answer/decline actions carried a
                // call id TDLib could never match.
                notificationManager.showIncomingCallNotification(partnerName, callManager.isVideoEnabled.value, currentCallId)

            CallState.MISSED -> {
                notificationManager.cancelIncomingCallNotification()
                // The notification helper existed but nothing ever called it, so a missed call
                // only landed in the in-app history and nobody was told.
                notificationManager.showMissedCallNotification(partnerName, callManager.isVideoEnabled.value)
                callHistoryManager.addFromCallState(callState, partnerId, partnerName, media, callManager.duration.value, outgoing)
                callManager.reset()
            }

            CallState.DECLINED, CallState.BUSY -> {
                notificationManager.cancelIncomingCallNotification()
                // We declined or hung up, so this one is always our own action.
                callHistoryManager.addFromCallState(callState, partnerId, partnerName, media, callManager.duration.value, true)
                callManager.reset()
            }

            CallState.FAILED -> {
                notificationManager.cancelIncomingCallNotification()
                callHistoryManager.addFromCallState(callState, partnerId, partnerName, media, callManager.duration.value, outgoing)
                // Hold FAILED briefly so the call screen can show the real TDLib reason; an
                // instant reset made the failure invisible - the screen flashed back to chat.
                delay(4000)
                callManager.reset()
            }

            CallState.ENDED -> {
                notificationManager.cancelIncomingCallNotification()
                callHistoryManager.addFromCallState(callState, partnerId, partnerName, media, callManager.duration.value, outgoing)
                callManager.reset()
            }

            else -> Unit
        }
    }

    Scaffold(
        topBar = {
            if (showTopBar) {
                CenterAlignedTopAppBar(
                    title = {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Schatz", style = MaterialTheme.typography.titleMedium)
                            Text(
                                text = when (connectionState) {
                                    ConnectionState.CONNECTED -> lastSeen
                                    ConnectionState.CONNECTING -> "Connecting..."
                                    ConnectionState.RECONNECTING -> "Reconnecting..."
                                    ConnectionState.OFFLINE -> "Offline"
                                    ConnectionState.AUTH_REQUIRED -> "Login required"
                                    ConnectionState.ERROR -> "Connection error"
                                },
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                        }
                    },
                    actions = {
                        val partner = connectionManager.partner.collectAsState().value
                        // A call button that silently does nothing is the worst kind of bug.
                        // The partner is null when their private chat could not be opened, and
                        // the old `partner?.let {}` swallowed the tap with no error, no log and
                        // nothing on screen. It now says why, and records it in the trail.
                        fun startCallFromHeader(isVideo: Boolean) {
                            val target = partner
                            if (target == null) {
                                CrashReporter.note("call button tapped but partner is null (video=$isVideo)")
                                android.widget.Toast.makeText(
                                    context,
                                    "Open the chat with your partner first",
                                    android.widget.Toast.LENGTH_SHORT
                                ).show()
                                return
                            }
                            callManager.startCall(target.id, isVideo)
                        }
                        IconButton(onClick = { startCallFromHeader(false) }) {
                            Icon(painterResource(R.drawable.ic_call_24), contentDescription = "Call")
                        }
                        IconButton(onClick = { startCallFromHeader(true) }) {
                            Icon(painterResource(R.drawable.ic_video_call_24), contentDescription = "Video call")
                        }
                        IconButton(onClick = { selected = Nav.SETTINGS }) {
                            Icon(painterResource(R.drawable.ic_more_vert_24), contentDescription = "Settings")
                        }
                    }
                )
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when {
                callOwnsScreen -> CallScreen(callManager = callManager, partnerName = partnerName)
                selected == Nav.CHAT -> ChatScreen(tdLib = tdLib, connectionManager = connectionManager, voiceManager = voiceManager)
                selected == Nav.CALLS -> CallHistoryScreen(callHistoryManager = callHistoryManager, callManager = callManager, partnerId = partnerId)
                selected == Nav.VAULT -> VaultScreenWithSync(syncManager = sharedVaultSyncManager, myId = myId, partnerName = partnerName, onBackToChat = { selected = Nav.CHAT })
                selected == Nav.SETTINGS -> SettingsScreen(
                    securityManager = securityManager,
                    enhancedVaultManager = enhancedVaultManager,
                    me = connectionManager.me.collectAsState().value,
                    isDark = isDark,
                    onToggleDark = onToggleDark,
                    onBackToChat = { selected = Nav.CHAT },
                    onOpenCallHistory = { selected = Nav.CALLS },
                    onOpenVault = { selected = Nav.VAULT },
                    onLogout = { securityManager.clearOnLogout(); tdLib.logout() },
                    onSetPin = { selected = Nav.SET_PIN }
                )
                selected == Nav.SET_PIN -> SetPinScreen(securityManager, onDone = { selected = Nav.SETTINGS }, onCancel = { selected = Nav.SETTINGS })
            }
        }
    }
}
