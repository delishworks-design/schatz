package com.schatz.production.managers

import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class ConnectionManager(private val tdLib: TdLibUpdateManager) {
    private val _state = MutableStateFlow(ConnectionState.CONNECTING)
    val state: StateFlow<ConnectionState> = _state
    private val _partner = MutableStateFlow<TdApi.User?>(null)
    val partner: StateFlow<TdApi.User?> = _partner
    private val _privateChat = MutableStateFlow<TdApi.Chat?>(null)
    val privateChat: StateFlow<TdApi.Chat?> = _privateChat
    private val _lastSeen = MutableStateFlow("Active now")
    val lastSeen: StateFlow<String> = _lastSeen
    var myId: Long = 0
    var partnerId: Long = 0

    fun init() {
        tdLib.getMe { me ->
            myId = me.id
            tdLib.getContacts { contacts ->
                val other = contacts.firstOrNull { it != myId }
                if(other != null) {
                    partnerId = other
                    tdLib.getUser(other) { user ->
                        _partner.value = user
                        createPrivateChat(other)
                        updateLastSeen(user)
                    }
                } else {
                    _state.value = ConnectionState.CONNECTING
                }
            }
        }
        tdLib.onUserUpdate = { user ->
            if(user.id == partnerId) {
                _partner.value = user
                updateLastSeen(user)
            }
            if(partnerId == 0L && user.id != myId) {
                if(isAuthorizedUser(user)) {
                    partnerId = user.id
                    _partner.value = user
                    createPrivateChat(user.id)
                }
            }
        }
    }

    private fun isAuthorizedUser(user: TdApi.User): Boolean { return true }

    private fun createPrivateChat(userId: Long) {
        _state.value = ConnectionState.CONNECTING
        tdLib.createPrivateChat(userId) { chat ->
            _privateChat.value = chat
            _state.value = ConnectionState.CONNECTED
        }
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

    fun reconnect() {
        _state.value = ConnectionState.RECONNECTING
        tdLib.getContacts { contacts ->
            val other = contacts.firstOrNull { it != myId }
            if(other != null) createPrivateChat(other) else _state.value = ConnectionState.OFFLINE
        }
    }
}
