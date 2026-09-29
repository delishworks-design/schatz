package com.schatz.production.managers

import android.util.Log
import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

private const val TAG = "SchatzConnection"

/**
 * Identifies the signed-in account and, when the user pairs one, the partner.
 *
 * The partner is chosen explicitly. An earlier version fell back to
 * `contacts.firstOrNull { it != myId }`, which silently paired the user with whichever contact
 * TDLib happened to return first.
 */
class ConnectionManager(private val tdLib: TdLibUpdateManager, private val securityManager: SecurityManager) {
    private val _state = MutableStateFlow(ConnectionState.CONNECTING)
    val state: StateFlow<ConnectionState> = _state
    private val _partner = MutableStateFlow<TdApi.User?>(null)
    val partner: StateFlow<TdApi.User?> = _partner
    private val _privateChat = MutableStateFlow<TdApi.Chat?>(null)
    val privateChat: StateFlow<TdApi.Chat?> = _privateChat
    private val _lastSeen = MutableStateFlow("Active now")
    val lastSeen: StateFlow<String> = _lastSeen

    // Observable, so a partner that resolves after the first composition still refreshes the UI.
    private val _myId = MutableStateFlow(0L)
    val myId: StateFlow<Long> = _myId
    private val _partnerId = MutableStateFlow(0L)
    val partnerId: StateFlow<Long> = _partnerId

    private val _pairingError = MutableStateFlow<String?>(null)
    val pairingError: StateFlow<String?> = _pairingError
    private val _isPairing = MutableStateFlow(false)
    val isPairing: StateFlow<Boolean> = _isPairing

    // The signed-in profile, so settings can show the real phone number, username and bio.
    private val _me = MutableStateFlow<TdApi.User?>(null)
    val me: StateFlow<TdApi.User?> = _me

    fun init() {
        tdLib.onUserUpdate = { user ->
            if (user.id == _partnerId.value && user.id != 0L) {
                _partner.value = user
                updateLastSeen(user)
            }
        }
        // The one-shot loadMe() in init() ran before TDLib was authorized, so on a fresh
        // install getMe came back as an error, myId stayed 0, and the pairing screen - which is
        // gated on myId - never appeared. Re-run it every time we actually become authorized.
        tdLib.onAuthState = { state ->
            if (state is TdApi.AuthorizationStateReady) loadMe()
        }
    }

    private fun loadMe() {
        _state.value = ConnectionState.CONNECTING
        tdLib.getMe(
            onSuccess = { user ->
                _me.value = user
                _myId.value = user.id
                _pairingError.value = null
                // Restore a previously paired partner before declaring the app unusable.
                restorePartner()
            },
            onFailure = { msg ->
                // TDLib gave up (not a transient "not ready"). Surface it instead of spinning
                // forever; the pairing screen shows this and offers Retry.
                Log.e(TAG, "getMe failed: $msg")
                _pairingError.value = "Could not load your Telegram account: $msg"
                _state.value = ConnectionState.ERROR
            }
        )
    }

    private fun restorePartner() {
        val saved = securityManager.getSession(KEY_PARTNER_ID)?.toLongOrNull() ?: 0L
        if (saved <= 0L) { _state.value = ConnectionState.AUTH_REQUIRED; return }
        _partnerId.value = saved
        resolvePartner(saved)
    }

    /** Re-reads the signed-in user. Worth calling after a transient GetMe failure. */
    fun retry() { loadMe() }

    /** Links the given username (with or without @) or numeric user id as the partner. */
    fun pair(input: String, onResult: (Boolean, String)->Unit) {
        val value = input.trim()
        if (value.isEmpty()) { onResult(false, "Enter a username or user id"); return }
        _isPairing.value = true
        _pairingError.value = null
        val onFound: (TdApi.User) -> Unit = { user -> applyPartner(user) }
        val onFail: (String) -> Unit = { msg -> _isPairing.value = false; _pairingError.value = msg; onResult(false, msg) }
        if (value.startsWith("@") || !value.all { it.isDigit() }) tdLib.searchPublicChat(value, onFound, onFail)
        else tdLib.findUserById(value, onFound, onFail)
    }

    private fun applyPartner(user: TdApi.User) {
        if (user.id == _myId.value) {
            val msg = "That is your own account"
            _isPairing.value = false
            _pairingError.value = msg
            return
        }
        _partnerId.value = user.id
        _partner.value = user
        securityManager.saveSession(KEY_PARTNER_ID, user.id.toString())
        updateLastSeen(user)
        _isPairing.value = false
        _pairingError.value = null
        createPrivateChat(user.id)
    }

    fun unpair() {
        _partnerId.value = 0L
        _partner.value = null
        _privateChat.value = null
        _state.value = ConnectionState.AUTH_REQUIRED
        securityManager.getSharedPreferencesEditor()?.remove(KEY_PARTNER_ID)?.apply()
    }

    private fun resolvePartner(userId: Long) {
        tdLib.getUser(userId,
            onSuccess = { user -> _partner.value = user; updateLastSeen(user); createPrivateChat(userId) },
            onFailure = { msg ->
                // The partner id no longer resolves, so drop the stale link instead of retrying it.
                _pairingError.value = msg
                _partnerId.value = 0L
                _state.value = ConnectionState.AUTH_REQUIRED
            }
        )
    }

    private fun createPrivateChat(userId: Long) {
        _state.value = ConnectionState.CONNECTING
        tdLib.createPrivateChat(userId,
            onSuccess = { chat ->
                _privateChat.value = chat
                _pairingError.value = null
                _state.value = ConnectionState.CONNECTED
            },
            onFailure = { msg ->
                // The partner is linked but the chat never opened. Unlink so the user lands back
                // on the pairing screen with a reason, instead of a header that says
                // "Connecting..." with no chat underneath it.
                Log.e(TAG, "createPrivateChat($userId) failed: $msg")
                _pairingError.value = "Could not open the chat with your partner: $msg"
                _partnerId.value = 0L
                _partner.value = null
                _privateChat.value = null
                _state.value = ConnectionState.AUTH_REQUIRED
                securityManager.getSharedPreferencesEditor()?.remove(KEY_PARTNER_ID)?.apply()
            })
    }

    private fun updateLastSeen(user: TdApi.User) {
        when(user.status) {
            is TdApi.UserStatusOnline -> _lastSeen.value = "Active now"
            is TdApi.UserStatusOffline -> {
                val wasOnline = (user.status as TdApi.UserStatusOffline).wasOnline
                val diff = (System.currentTimeMillis()/1000 - wasOnline).toInt()
                _lastSeen.value = when {
                    diff < 60 -> "Active now"
                    diff < 3600 -> "Active ${diff/60}m ago"
                    diff < 86400 -> "Active ${diff/3600}h ago"
                    else -> "Active ${diff/86400}d ago"
                }
            }
            is TdApi.UserStatusRecently -> _lastSeen.value = "Active recently"
            is TdApi.UserStatusLastWeek -> _lastSeen.value = "Active last week"
            else -> _lastSeen.value = "Active now"
        }
    }

    companion object {
        const val KEY_PARTNER_ID = "partner_id"
    }
}
