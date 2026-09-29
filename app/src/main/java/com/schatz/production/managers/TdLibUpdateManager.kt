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

        // libtdjni.so ships in jniLibs but Android never auto-loads it. Without this the very
        // first Client.execute() throws UnsatisfiedLinkError, which is an Error (not an
        // Exception) and therefore escapes the catch below, crashing the app on launch.
        init {
            try {
                System.loadLibrary("tdjni")
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to load libtdjni.so", e)
                throw e
            }
        }
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

    // Call-request failures have their own channel. Routing them through the global onError
    // above made EVERY TDLib error (a failed getUser, a 404 on a username lookup, ...) look
    // like a call failure to the UI - that is what filled the screen with bogus call failures.
    var onCallError: ((TdApi.Error)->Unit)? = null

    // tgcalls handshake channel: TDLib only relays the bytes, Phase 3 hands them to tgcalls.
    var onCallSignalingData: ((callId: Int, data: ByteArray)->Unit)? = null

    /** Fired by TdApi.UpdateMessageSendSucceeded / Failed so the chat can move the bubble off SENDING. */
    var onMessageSendSucceeded: ((Long)->Unit)? = null
    var onMessageSendFailed: ((Long, String)->Unit)? = null

    /** Live reaction tallies for a message (TdApi.UpdateMessageReactions). */
    var onMessageReactions: ((chatId: Long, messageId: Long, reactions: Array<TdApi.MessageReaction>)->Unit)? = null

    /** The partner's chat action (typing, ...); the UI clears it after a short timeout. */
    var onChatAction: ((chatId: Long, senderId: TdApi.MessageSender, action: TdApi.ChatAction)->Unit)? = null

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
                useTestDc = false
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
        } catch (e: Throwable) {
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
                onMessageSendSucceeded?.invoke(obj.message?.id ?: 0L)
            }
            is TdApi.UpdateMessageSendFailed -> {
                // MessageStatus.FAILED was rendered by the UI but never assigned, so a rejected
                // message stayed on the sending tick forever.
                Log.e(TAG, "Message send failed: ${obj.error.code} ${obj.error.message}")
                onMessageSendFailed?.invoke(obj.message?.id ?: obj.oldMessageId, obj.error.message)
            }
            is TdApi.UpdateChatReadInbox,
            is TdApi.UpdateChatReadOutbox -> {
                // Read updates
            }
            is TdApi.UpdateMessageReactions -> {
                onMessageReactions?.invoke(obj.chatId, obj.messageId, obj.reactions)
            }
            is TdApi.UpdateChatAction -> {
                // Only the partner's action matters to a 2-user chat; our own echo is ignored.
                onChatAction?.invoke(obj.chatId, obj.senderId, obj.action)
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
                // Drive any watcher registered by downloadFile; without this a download could
                // never reach its completion callback.
                driveDownloadWatchers(obj.file)
            }
            is TdApi.UpdateFileGenerationStart,
            is TdApi.UpdateFileGenerationStop -> {
                // File generation for uploads
            }

            // CALL UPDATES
            is TdApi.UpdateCall -> {
                onCallUpdate?.invoke(obj.call)
            }
            is TdApi.UpdateNewCallSignalingData -> {
                // Handshake bytes for tgcalls. TDLib relays them untouched.
                onCallSignalingData?.invoke(obj.callId, obj.data)
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
    fun getUser(userId: Long, callback: (TdApi.User)->Unit) { client?.send(TdApi.GetUser(userId)) { res -> if(res is TdApi.User) callback(res); reportError(res) } }

    // CHATS
    fun createPrivateChat(userId: Long, callback: (TdApi.Chat)->Unit) { client?.send(TdApi.CreatePrivateChat(userId, false)) { res -> if(res is TdApi.Chat) callback(res); reportError(res) } }
    fun getChat(chatId: Long, callback: (TdApi.Chat)->Unit) { client?.send(TdApi.GetChat(chatId)) { res -> if(res is TdApi.Chat) callback(res) } }

    // PAIRING
    // Resolves a partner from a public username or a numeric user id, and reports failures
    // instead of failing silently, so the UI can say what went wrong.
    fun searchPublicChat(username: String, onSuccess: (TdApi.User)->Unit, onFailure: (String)->Unit) {
        val handle = username.trim().removePrefix("@")
        if (handle.isEmpty()) { onFailure("Enter a username or user id"); return }
        client?.send(TdApi.SearchPublicChat(handle)) { res ->
            when {
                res is TdApi.Chat -> {
                    val private = res.type as? TdApi.ChatTypePrivate
                    if (private == null) onFailure("'$handle' is not a personal account")
                    else getUser(private.userId, onSuccess) { onFailure("Found '$handle' but could not load the profile") }
                }
                res is TdApi.Error && res.code == 400 -> onFailure("No public account named '$handle'")
                res is TdApi.Error -> onFailure("Lookup failed: ${res.message}")
                else -> onFailure("Lookup failed")
            }
        }
    }

    fun findUserById(rawId: String, onSuccess: (TdApi.User)->Unit, onFailure: (String)->Unit) {
        val id = rawId.trim().removePrefix("@").toLongOrNull()
        if (id == null || id <= 0L) { onFailure("That is not a valid user id"); return }
        getUser(id, onSuccess) { onFailure("No user with id $id") }
    }

    fun getUser(userId: Long, onSuccess: (TdApi.User)->Unit, onFailure: (String)->Unit = {}) {
        client?.send(TdApi.GetUser(userId)) { res ->
            when (res) {
                is TdApi.User -> onSuccess(res)
                is TdApi.Error -> onFailure("User $userId not found (${res.message})")
                else -> onFailure("User $userId not found")
            }
        }
    }

    // Sends the read receipt. TDLib does not mark messages read on its own, so without this the
    // peer never sees a read tick. The MessageSource is required by this TDLib version.
    fun viewMessages(chatId: Long, messageIds: LongArray) {
        if (messageIds.isEmpty()) return
        client?.send(TdApi.ViewMessages(chatId, messageIds, TdApi.MessageSourceChatList(), true)) { Log.d(TAG, "ViewMessages: $it") }
    }

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
        client?.send(TdApi.GetMessage(chatId, messageId)) { res -> if (res is TdApi.Message) callback(res) }
    }

    /** Local file state without triggering a download - used to pick up files from an earlier session. */
    fun getFile(fileId: Int, callback: (TdApi.File)->Unit) {
        if (fileId == 0) return
        client?.send(TdApi.GetFile(fileId)) { res -> if (res is TdApi.File) callback(res) }
    }

    // Server-side message search. The local filter only sees what has been paged in so far.
    // topicId/senderId/filter are optional flag fields in this TDLib version -> null = absent.
    fun searchChatMessages(chatId: Long, query: String, callback: (List<TdApi.Message>)->Unit) {
        if (query.isBlank()) { callback(emptyList()); return }
        client?.send(TdApi.SearchChatMessages(chatId, null, query, null, 0, 0, 50, null)) { res ->
            when (res) {
                is TdApi.FoundChatMessages -> callback(res.messages.toList())
                is TdApi.Error -> { Log.e(TAG, "SearchChatMessages: ${res.message}"); callback(emptyList()) }
                else -> callback(emptyList())
            }
        }
    }

    /** Tells the partner we are typing. Cancel comes from ChatActionCancel or from sending. */
    fun sendTyping(chatId: Long) {
        client?.send(TdApi.SendChatAction(chatId, null, null, TdApi.ChatActionTyping())) { res ->
            if (res is TdApi.Error) Log.d(TAG, "SendChatAction: ${res.code} ${res.message}")
        }
    }

    fun addReaction(chatId: Long, messageId: Long, emoji: String) {
        client?.send(TdApi.AddMessageReaction(chatId, messageId, TdApi.ReactionTypeEmoji(emoji), true, false)) { res ->
            if (res is TdApi.Error) Log.e(TAG, "AddReaction: ${res.message}")
        }
    }

    fun removeReaction(chatId: Long, messageId: Long, emoji: String) {
        client?.send(TdApi.RemoveMessageReaction(chatId, messageId, TdApi.ReactionTypeEmoji(emoji))) { res ->
            if (res is TdApi.Error) Log.e(TAG, "RemoveReaction: ${res.message}")
        }
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

    /**
     * Starts a download and invokes onProgress for every subsequent TdApi.UpdateFile, then
     * onComplete once is_downloading_completed turns true.
     *
     * The previous version only read the immediate response of DownloadFile, which reports the
     * file's current state and is therefore almost always not-yet-complete, so a download that had
     * just started was reported as a failure and never retried.
     */
    fun downloadFile(
        fileId: Int,
        priority: Int = 32,
        onProgress: ((TdApi.File) -> Unit)? = null,
        onComplete: (TdApi.File) -> Unit = {}
    ) {
        if (fileId == 0) return
        val watcher = DownloadWatcher(fileId, onProgress, onComplete)
        synchronized(downloadWatchers) { downloadWatchers[fileId] = watcher }

        client?.send(TdApi.DownloadFile(fileId, priority, 0, 0, false)) { res ->
            if (res is TdApi.File) watcher.onFile(res)
            else if (res is TdApi.Error) {
                Log.e(TAG, "DownloadFile($fileId) failed: ${res.message}")
                synchronized(downloadWatchers) { downloadWatchers.remove(fileId) }
            }
        }
    }

    private class DownloadWatcher(
        private val fileId: Int,
        private val onProgress: ((TdApi.File) -> Unit)?,
        private val onComplete: (TdApi.File) -> Unit
    ) {
        fun onFile(file: TdApi.File) {
            if (file.id != fileId) return
            if (file.local?.isDownloadingCompleted == true) onComplete(file)
            else onProgress?.invoke(file)
        }
    }

    private val downloadWatchers = java.util.concurrent.ConcurrentHashMap<Int, DownloadWatcher>()

    private fun driveDownloadWatchers(file: TdApi.File) {
        val watcher = synchronized(downloadWatchers) { downloadWatchers[file.id] } ?: return
        if (file.local?.isDownloadingCompleted == true) {
            synchronized(downloadWatchers) { downloadWatchers.remove(file.id) }
            watcher.onFile(file)
        } else {
            watcher.onFile(file)
        }
    }

    fun cancelDownload(fileId: Int) {
        client?.send(TdApi.CancelDownloadFile(fileId, false)) {}
    }

    fun cancelUpload(fileId: Int) {
        client?.send(TdApi.CancelPreliminaryUploadFile(fileId)) {}
    }

    // CALLS
    // core.telegram.org/api/calls fixes these values for tgcalls: min_layer 65 and max_layer 92
    // are the immutable libtgvoip layers, and library_versions must be the ordered list of
    // supported tgcalls protocol versions (preferred first). The previous (2048, 1) had
    // max < min (400 on every call) and the follow-up (0, 0, null) sent no versions at all,
    // so the server had nothing to negotiate the media protocol with.
    private fun callProtocol(): TdApi.CallProtocol = TdApi.CallProtocol(
        true, true, 65, 92,
        arrayOf("13.0.0", "12.0.0", "9.0.0", "8.0.0", "7.0.0", "5.0.0", "2.7.7")
    )

    fun createCall(userId: Long, isVideo: Boolean) { client?.send(TdApi.CreateCall(userId, callProtocol(), isVideo)) { res -> Log.d(TAG, "CreateCall: $res"); reportCallError("CreateCall", res) } }
    fun acceptCall(callId: Int) { client?.send(TdApi.AcceptCall(callId, callProtocol())) { res -> Log.d(TAG, "AcceptCall: $res"); reportCallError("AcceptCall", res) } }
    fun discardCall(callId: Int, isDisconnected: Boolean = false, duration: Int = 0) {
        client?.send(TdApi.DiscardCall(callId, isDisconnected, "", duration, false, 0)) { res -> Log.d(TAG, "DiscardCall: $res") }
    }

    /** One leg of the tgcalls handshake. TDLib does not interpret these bytes, it only relays them. */
    fun sendCallSignalingData(callId: Int, data: ByteArray) {
        client?.send(TdApi.SendCallSignalingData(callId, data)) { res -> if (res is TdApi.Error) Log.e(TAG, "SendCallSignalingData: ${res.message}") }
    }

    // TDLib mutes the actual WebRTC stream through this option; the local UI flag alone silences
    // nothing on the wire.
    fun setMuted(muted: Boolean) {
        client?.send(TdApi.SetOption("mute", TdApi.OptionValueBoolean(muted))) { res -> Log.d(TAG, "SetOption mute: $res") }
    }

    // Raised by non-call requests (getUser, createPrivateChat, ...). Nobody subscribes to the
    // global onError any more; the call UI listens only to onCallError, so an ordinary lookup
    // failure can never masquerade as a failed call.
    private fun reportError(res: TdApi.Object) {
        if (res is TdApi.Error) Log.e(TAG, "Request error: ${res.code} ${res.message}")
    }

    // Call-request failures go to the call UI with the real TDLib message attached.
    private fun reportCallError(op: String, res: TdApi.Object) {
        if (res is TdApi.Error) {
            Log.e(TAG, "$op failed: ${res.code} ${res.message}")
            onCallError?.invoke(res)
        }
    }

    fun close() { client?.send(TdApi.Close()) {} }
}
