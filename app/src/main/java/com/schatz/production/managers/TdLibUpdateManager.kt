package com.schatz.production.managers

import android.util.Log
import org.drinkless.tdlib.Client
import org.drinkless.tdlib.TdApi
import java.io.File
import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

// FULL CENTRALIZED UPDATE ARCHITECTURE: TDLib -> Update Manager -> Application State -> UI
// No longer simple callback - handles ALL TDLib updates

enum class ConnectionState { CONNECTED, CONNECTING, RECONNECTING, OFFLINE, AUTH_REQUIRED, ERROR }

class TdLibUpdateManager(private val context: Context) {
    companion object {
        const val API_ID = 34650307
        const val API_HASH = "ed1226c685ca638c63c28b904433da3c"
        const val TAG = "SchatzTdLib"
    }

    private var client: Client? = null

    // Application State flows
    private val _authState = MutableStateFlow<TdApi.AuthorizationState?>(null)
    val authState: StateFlow<TdApi.AuthorizationState?> = _authState

    private val _connectionState = MutableStateFlow(ConnectionState.CONNECTING)
    val connectionState: StateFlow<ConnectionState> = _connectionState

    private val _chats = MutableStateFlow<Map<Long, TdApi.Chat>>(emptyMap())
    val chats: StateFlow<Map<Long, TdApi.Chat>> = _chats

    private val _users = MutableStateFlow<Map<Long, TdApi.User>>(emptyMap())
    val users: StateFlow<Map<Long, TdApi.User>> = _users

    private val _files = MutableStateFlow<Map<Int, TdApi.File>>(emptyMap())
    val files: StateFlow<Map<Int, TdApi.File>> = _files

    // Event callbacks - centralized, not scattered
    var onAuthState: ((TdApi.AuthorizationState)->Unit)? = null
    var onNewMessage: ((TdApi.Message)->Unit)? = null
    var onMessageEdited: ((TdApi.Message)->Unit)? = null
    var onMessageDeleted: ((Long, Long)->Unit)? = null // chatId, messageId
    var onMessageRead: ((Long, Long)->Unit)? = null // chatId, messageId
    var onUserUpdate: ((TdApi.User)->Unit)? = null
    var onChatUpdate: ((TdApi.Chat)->Unit)? = null
    var onChatLastMessage: ((Long, TdApi.Message?)->Unit)? = null
    var onFileUpdate: ((TdApi.File)->Unit)? = null
    var onFileDownloadUpdate: ((Int, Int)->Unit)? = null // fileId, progress
    var onFileUploadUpdate: ((Int, Int)->Unit)? = null
    var onCallUpdate: ((TdApi.Call)->Unit)? = null
    var onNetworkState: ((ConnectionState)->Unit)? = null
    var onError: ((TdApi.Error)->Unit)? = null

    // Multiple subscribers can observe the same update without overwriting each
    // other (the single var above is kept for backward compatibility).
    private val newMessageListeners = java.util.concurrent.CopyOnWriteArrayList<((TdApi.Message) -> Unit)>()
    private val messageDeletedListeners = java.util.concurrent.CopyOnWriteArrayList<((Long, Long) -> Unit)>()

    fun addNewMessageListener(listener: (TdApi.Message) -> Unit) { newMessageListeners.add(listener) }
    fun removeNewMessageListener(listener: (TdApi.Message) -> Unit) { newMessageListeners.remove(listener) }
    fun addMessageDeletedListener(listener: (Long, Long) -> Unit) { messageDeletedListeners.add(listener) }
    fun removeMessageDeletedListener(listener: (Long, Long) -> Unit) { messageDeletedListeners.remove(listener) }

    fun init() {
        try {
            Client.execute(TdApi.SetLogVerbosityLevel(1))
            client = Client.create({ obj -> handleUpdate(obj) }, null, null)
            val params = TdApi.SetTdlibParameters().apply {
                databaseDirectory = File(context.filesDir, "tdlib").absolutePath
                filesDirectory = File(context.filesDir, "tdlib_files").absolutePath
                useTestDc = true
                useFileDatabase = true
                useChatInfoDatabase = true
                useMessageDatabase = true
                systemLanguageCode = "en"
                deviceModel = "Schatz Couple"
                applicationVersion = "12.2-full"
                apiId = API_ID
                apiHash = API_HASH
            }
            client?.send(params) { result -> Log.d(TAG, "SetParams: $result") }
        } catch (e: Exception) {
            Log.e(TAG, "Init error", e)
            _connectionState.value = ConnectionState.ERROR
        }
    }

    private fun handleUpdate(obj: TdApi.Object) {
        when(obj) {
            // AUTH UPDATES
            is TdApi.UpdateAuthorizationState -> {
                _authState.value = obj.authorizationState
                onAuthState?.invoke(obj.authorizationState)
                _connectionState.value = when(obj.authorizationState) {
                    is TdApi.AuthorizationStateReady -> ConnectionState.CONNECTED
                    is TdApi.AuthorizationStateWaitPhoneNumber,
                    is TdApi.AuthorizationStateWaitCode,
                    is TdApi.AuthorizationStateWaitPassword -> ConnectionState.AUTH_REQUIRED
                    is TdApi.AuthorizationStateWaitTdlibParameters -> ConnectionState.CONNECTING
                    is TdApi.AuthorizationStateLoggingOut,
                    is TdApi.AuthorizationStateClosed -> ConnectionState.OFFLINE
                    else -> ConnectionState.CONNECTING
                }
                onNetworkState?.invoke(_connectionState.value)
            }

            // MESSAGE UPDATES
            is TdApi.UpdateNewMessage -> {
                onNewMessage?.invoke(obj.message)
                newMessageListeners.forEach { it(obj.message) }
            }
            is TdApi.UpdateMessageEdited -> {
                getMessage(obj.chatId, obj.messageId) { edited -> onMessageEdited?.invoke(edited) }
            }
            is TdApi.UpdateDeleteMessages -> {
                obj.messageIds.forEach { msgId ->
                    onMessageDeleted?.invoke(obj.chatId, msgId)
                    messageDeletedListeners.forEach { it(obj.chatId, msgId) }
                }
            }
            is TdApi.UpdateMessageSendSucceeded -> {
                // Message sent successfully
            }
            is TdApi.UpdateMessageSendFailed -> {
                // Message failed - retry logic
                Log.e(TAG, "Message send failed: ${obj.error.code} ${obj.error.message}")
            }
            is TdApi.UpdateChatReadInbox,
            is TdApi.UpdateChatReadOutbox -> {
                // Read updates
            }

            // USER UPDATES
            is TdApi.UpdateUser -> {
                val current = _users.value.toMutableMap()
                current[obj.user.id] = obj.user
                _users.value = current
                onUserUpdate?.invoke(obj.user)
            }
            is TdApi.UpdateUserStatus -> {
                // User online/offline
            }

            // CHAT UPDATES
            is TdApi.UpdateNewChat -> {
                val current = _chats.value.toMutableMap()
                current[obj.chat.id] = obj.chat
                _chats.value = current
                onChatUpdate?.invoke(obj.chat)
            }
            is TdApi.UpdateChatTitle -> {
                _chats.value[obj.chatId]?.let { chat ->
                    val updated = chat.apply { title = obj.title }
                    val current = _chats.value.toMutableMap()
                    current[obj.chatId] = updated
                    _chats.value = current
                }
            }
            is TdApi.UpdateChatLastMessage -> {
                onChatLastMessage?.invoke(obj.chatId, obj.lastMessage)
            }
            is TdApi.UpdateChatPhoto,
            is TdApi.UpdateChatPermissions,
            is TdApi.UpdateChatNotificationSettings -> {
                // Chat metadata updates
            }

            // FILE UPDATES - FULL FILE HANDLING
            is TdApi.UpdateFile -> {
                val current = _files.value.toMutableMap()
                current[obj.file.id] = obj.file
                _files.value = current
                onFileUpdate?.invoke(obj.file)
            }
            is TdApi.UpdateFileGenerationStart,
            is TdApi.UpdateFileGenerationStop -> {
                // File generation for uploads
            }

            // CALL UPDATES
            is TdApi.UpdateCall -> {
                onCallUpdate?.invoke(obj.call)
            }
            is TdApi.UpdateGroupCall,
            is TdApi.UpdateGroupCallParticipant -> {
                // Group calls not needed for 2-user
            }

            // NETWORK UPDATES
            is TdApi.UpdateConnectionState -> {
                val state = when(obj.state) {
                    is TdApi.ConnectionStateReady -> ConnectionState.CONNECTED
                    is TdApi.ConnectionStateConnecting -> ConnectionState.CONNECTING
                    is TdApi.ConnectionStateConnectingToProxy -> ConnectionState.CONNECTING
                    is TdApi.ConnectionStateUpdating -> ConnectionState.CONNECTED
                    is TdApi.ConnectionStateWaitingForNetwork -> ConnectionState.RECONNECTING
                    else -> ConnectionState.OFFLINE
                }
                _connectionState.value = state
                onNetworkState?.invoke(state)
            }

            // ERROR
            is TdApi.Error -> {
                Log.e(TAG, "TDLib Error: ${obj.code} ${obj.message}")
                onError?.invoke(obj)
                if(obj.code == 401) _connectionState.value = ConnectionState.AUTH_REQUIRED
                if(obj.code >= 500) _connectionState.value = ConnectionState.ERROR
            }
        }
    }

    // AUTH
    fun sendPhone(phone: String) { client?.send(TdApi.SetAuthenticationPhoneNumber(phone, null)) { Log.d(TAG, "SendPhone: $it") } }
    fun sendCode(code: String) { client?.send(TdApi.CheckAuthenticationCode(code)) { Log.d(TAG, "CheckCode: $it") } }
    fun sendPassword(password: String) { client?.send(TdApi.CheckAuthenticationPassword(password)) {} }
    fun logout() { client?.send(TdApi.LogOut()) {} }

    // USERS
    fun getMe(callback: (TdApi.User)->Unit) { client?.send(TdApi.GetMe()) { res -> if(res is TdApi.User) callback(res) } }
    fun getContacts(callback: (List<Long>)->Unit) { client?.send(TdApi.GetContacts()) { res -> if(res is TdApi.Users) callback(res.userIds.toList()) } }
    fun getUser(userId: Long, callback: (TdApi.User)->Unit) { client?.send(TdApi.GetUser(userId)) { res -> if(res is TdApi.User) callback(res) } }

    // CHATS
    fun createPrivateChat(userId: Long, callback: (TdApi.Chat)->Unit) { client?.send(TdApi.CreatePrivateChat(userId, false)) { res -> if(res is TdApi.Chat) callback(res) } }
    fun getChat(chatId: Long, callback: (TdApi.Chat)->Unit) { client?.send(TdApi.GetChat(chatId)) { res -> if(res is TdApi.Chat) callback(res) } }

    // MESSAGES - WITH PAGINATION
    fun sendMessage(chatId: Long, text: String, replyTo: Long = 0, callback: (TdApi.Message)->Unit = {}) {
        val content = TdApi.InputMessageText(TdApi.FormattedText(text, null), null, false)
        val reply = if(replyTo != 0L) TdApi.InputMessageReplyToMessage(replyTo, null, 0, null) else null
        client?.send(TdApi.SendMessage(chatId, null, reply, null, null, content)) { res -> if(res is TdApi.Message) callback(res) }
    }

    fun editMessage(chatId: Long, messageId: Long, newText: String, callback: (TdApi.Message)->Unit = {}) {
        val content = TdApi.InputMessageText(TdApi.FormattedText(newText, null), null, false)
        client?.send(TdApi.EditMessageText(chatId, messageId, null, content)) { res -> if(res is TdApi.Message) callback(res) }
    }

    fun deleteMessage(chatId: Long, messageId: Long, forBoth: Boolean = true, callback: ()->Unit = {}) {
        client?.send(TdApi.DeleteMessages(chatId, longArrayOf(messageId), forBoth)) { _ -> callback() }
    }

    fun getChatHistory(chatId: Long, fromMessageId: Long = 0, offset: Int = 0, limit: Int = 50, callback: (TdApi.Messages)->Unit) {
        client?.send(TdApi.GetChatHistory(chatId, fromMessageId, offset, limit, false)) { res -> if(res is TdApi.Messages) callback(res) }
    }

    fun getMessage(chatId: Long, messageId: Long, callback: (TdApi.Message)->Unit) {
        client?.send(TdApi.GetMessage(chatId, messageId)) { res -> if(res is TdApi.Message) callback(res) }
    }

    // FILES - FULL HANDLING
    fun sendFile(chatId: Long, filePath: String, caption: String = "", callback: (TdApi.Message)->Unit = {}) {
        val file = TdApi.InputFileLocal(filePath)
        val formatted = TdApi.FormattedText(caption, null)
        val content = TdApi.InputMessageDocument(file, null, false, formatted)
        client?.send(TdApi.SendMessage(chatId, null, null, null, null, content)) { res -> if(res is TdApi.Message) callback(res) }
    }

    fun sendPhoto(chatId: Long, filePath: String, caption: String = "", callback: (TdApi.Message)->Unit = {}) {
        val file = TdApi.InputFileLocal(filePath)
        val formatted = TdApi.FormattedText(caption, null)
        val content = TdApi.InputMessagePhoto(file, null, null, null, 0, 0, formatted, false, null, false)
        client?.send(TdApi.SendMessage(chatId, null, null, null, null, content)) { res -> if(res is TdApi.Message) callback(res) }
    }

    fun sendVideo(chatId: Long, filePath: String, caption: String = "", callback: (TdApi.Message)->Unit = {}) {
        val file = TdApi.InputFileLocal(filePath)
        val formatted = TdApi.FormattedText(caption, null)
        val content = TdApi.InputMessageVideo(file, null, null, 0, null, 0, 0, 0, false, formatted, false, null, false)
        client?.send(TdApi.SendMessage(chatId, null, null, null, null, content)) { res -> if(res is TdApi.Message) callback(res) }
    }

    fun downloadFile(fileId: Int, priority: Int = 32, callback: (TdApi.File)->Unit = {}) {
        client?.send(TdApi.DownloadFile(fileId, priority, 0, 0, false)) { res -> if(res is TdApi.File) callback(res) }
    }

    fun cancelDownload(fileId: Int) {
        client?.send(TdApi.CancelDownloadFile(fileId, false)) {}
    }

    fun cancelUpload(fileId: Int) {
        client?.send(TdApi.CancelPreliminaryUploadFile(fileId)) {}
    }

    // CALLS
    fun createCall(userId: Long, isVideo: Boolean) { client?.send(TdApi.CreateCall(userId, TdApi.CallProtocol(true, true, 2048, 1, arrayOf("1.0")), isVideo)) { res -> Log.d(TAG, "CreateCall: $res") } }
    fun acceptCall(callId: Int, protocol: TdApi.CallProtocol) { client?.send(TdApi.AcceptCall(callId, protocol)) {} }
    fun discardCall(callId: Int) { client?.send(TdApi.DiscardCall(callId, false, "", 0, false, 0)) {} }

    fun close() { client?.send(TdApi.Close()) {} }
}
