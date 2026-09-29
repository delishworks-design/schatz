package com.schatz.production

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import com.schatz.production.managers.*
import com.schatz.production.ui.SchatzApp
import com.schatz.production.ui.theme.SchatzTheme

/**
 * Carries an action that arrived through a notification tap or button. The notification builder
 * puts these extras in, but nothing ever read them, so answering a call from the shade did nothing.
 *
 * kind/callId are Compose snapshot state, not plain volatile fields: a plain field change never
 * invalidates composition, so the LaunchedEffect that performs the action only fired if something
 * else happened to recompose the screen - taps from the shade on an already-running activity
 * could be silently dropped.
 */
class PendingCallAction {
    companion object {
        const val EXTRA_ANSWER = "answer_call_id"
        const val EXTRA_DECLINE = "decline_call_id"
        const val EXTRA_INCOMING = "incoming_call_id"
        const val EXTRA_OPEN_CALLS = "open_calls"
    }

    enum class Kind { NONE, ANSWER, DECLINE, OPEN_CALLS }

    var kind by mutableStateOf(Kind.NONE)
        private set
    var callId by mutableStateOf(0)
        private set

    // Increments on every actionable tap so two identical taps (same call id) still fire.
    var tick by mutableStateOf(0)
        private set

    fun consume(intent: Intent?) {
        val extra = intent ?: return
        when {
            extra.hasExtra(EXTRA_ANSWER) -> { kind = Kind.ANSWER; callId = extra.getIntExtra(EXTRA_ANSWER, 0); tick++ }
            extra.hasExtra(EXTRA_DECLINE) -> { kind = Kind.DECLINE; callId = extra.getIntExtra(EXTRA_DECLINE, 0); tick++ }
            extra.hasExtra(EXTRA_OPEN_CALLS) -> { kind = Kind.OPEN_CALLS; callId = 0; tick++ }
            // No action in this intent. Previously this reset kind to NONE, which wiped the
            // tap on the very next onStart (the extras had already been consumed), so the
            // Answer/Decline buttons from the notification shade never reached the call at all.
            else -> Unit
        }
        if (tick > 0) {
            // A configuration change would otherwise re-apply the same tap.
            extra.removeExtra(EXTRA_ANSWER)
            extra.removeExtra(EXTRA_DECLINE)
            extra.removeExtra(EXTRA_INCOMING)
            extra.removeExtra(EXTRA_OPEN_CALLS)
        }
    }
}

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
    private lateinit var enhancedVaultManager: EnhancedVaultManager
    private lateinit var autoLockManager: AutoLockManager
    private lateinit var callEnhancedManager: CallEnhancedManager
    private val pendingCallAction = PendingCallAction()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Installed before anything else so a crash in the TDLib/tgcalls startup path is still
        // captured and can be read back from Settings on the next launch.
        CrashReporter.install(this)
        securityManager = SecurityManager(this)
        // Order matters twice over. TdLibUpdateManager must exist before CallManager can be given
        // it, and callManager.init() must run before tdLib.init() starts delivering updates,
        // otherwise any call update arriving in that window is dropped on a null listener.
        tdLib = TdLibUpdateManager(this)
        callManager = CallManager(tdLib, applicationContext)
        callManager.init()
        tdLib.init()
        connectionManager = ConnectionManager(tdLib, securityManager)
        connectionManager.init()
        vaultManager = VaultManager(this)
        voiceManager = VoiceMessageManager(this)
        callHistoryManager = CallHistoryManager(this)
        notificationManager = SchatzNotificationManager(this)
        fileManager = FileManager(this, tdLib)
        chatManager = ChatManager(tdLib)
        sharedVaultSyncManager = SharedVaultSyncManager(this, tdLib, vaultManager)
        enhancedVaultManager = EnhancedVaultManager(this)
        autoLockManager = AutoLockManager(this, securityManager)
        callEnhancedManager = CallEnhancedManager(this, callManager)

        pendingCallAction.consume(intent)

        setContent {
            var isDark by remember { mutableStateOf(false) }
            val actionKind = pendingCallAction.kind
            val actionCallId = pendingCallAction.callId
            val actionTick = pendingCallAction.tick

            // Missed-call notification tap -> jump to the call history (see SchatzApp).
            var openCallsTick by remember { mutableStateOf(0) }

            // Answer/decline tapped from the notification shade, handled once per tap.
            LaunchedEffect(actionKind, actionCallId, actionTick) {
                when (actionKind) {
                    PendingCallAction.Kind.ANSWER -> { callManager.acceptCall(actionCallId); notificationManager.cancelIncomingCallNotification() }
                    PendingCallAction.Kind.DECLINE -> { callManager.declineCall(actionCallId); notificationManager.cancelIncomingCallNotification() }
                    PendingCallAction.Kind.OPEN_CALLS -> openCallsTick++
                    else -> Unit
                }
            }

            // A live call needs the foreground service (phoneCall|microphone|camera), otherwise
            // Android tears the microphone down as soon as the app leaves the foreground - the
            // service was written but never started by anything. Terminal states stop it.
            val callState by callManager.callState.collectAsState()
            LaunchedEffect(callState) {
                val serviceIntent = Intent(this@MainActivity, CallService::class.java)
                if (callState.isLive()) {
                    // Android 12+ can refuse a background start; the full-screen intent brings
                    // this activity forward anyway, so a refusal is not fatal.
                    try { startForegroundService(serviceIntent) } catch (t: Throwable) {
                        android.util.Log.w("SchatzMain", "CallService start refused: $t")
                    }
                } else {
                    stopService(serviceIntent)
                }
            }

            SchatzTheme(darkTheme = isDark) {
                SchatzApp(
                    tdLib = tdLib,
                    connectionManager = connectionManager,
                    callManager = callManager,
                    securityManager = securityManager,
                    voiceManager = voiceManager,
                    callHistoryManager = callHistoryManager,
                    notificationManager = notificationManager,
                    fileManager = fileManager,
                    chatManager = chatManager,
                    sharedVaultSyncManager = sharedVaultSyncManager,
                    enhancedVaultManager = enhancedVaultManager,
                    autoLockManager = autoLockManager,
                    callEnhancedManager = callEnhancedManager,
                    isDark = isDark,
                    onToggleDark = { isDark = !isDark },
                    openCallsTick = openCallsTick
                )
            }
        }
    }

    /** Required for the Answer/Decline buttons to reach a running activity. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingCallAction.consume(intent)
    }

    override fun onStart() {
        super.onStart()
        // An activity that was already running when the tap arrived still needs to pick it up.
        pendingCallAction.consume(intent)
    }

    override fun onDestroy() { callManager.release(); tdLib.close(); voiceManager.cleanup(); super.onDestroy() }
}
