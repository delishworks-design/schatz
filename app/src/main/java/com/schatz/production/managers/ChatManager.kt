package com.schatz.production.managers

import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import com.schatz.production.models.ChatMessage
import com.schatz.production.models.MessageStatus
import com.schatz.production.models.MediaType

class ChatManager(private val tdLib: TdLibUpdateManager) {
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages

    private val _isLoadingHistory = MutableStateFlow(false)
    val isLoadingHistory: StateFlow<Boolean> = _isLoadingHistory

    private val _hasMoreHistory = MutableStateFlow(true)
    val hasMoreHistory: StateFlow<Boolean> = _hasMoreHistory

    private var currentChatId: Long = 0
    private var oldestMessageId: Long = 0
    private var myId: Long = 0

    private val _dateSeparators = MutableStateFlow<Map<Long, String>>(emptyMap())
    val dateSeparators: StateFlow<Map<Long, String>> = _dateSeparators

    fun init(myId: Long, chatId: Long) {
        this.myId = myId
        this.currentChatId = chatId
        loadInitialHistory()

        // Listen for new messages via central Update Manager
        tdLib.onNewMessage = { tdMessage ->
            if(tdMessage.chatId == currentChatId) {
                val chatMsg = tdMessage.toChatMessage(myId)
                _messages.value = _messages.value + chatMsg
                // Mark as read
                markAsRead(tdMessage.chatId, tdMessage.id)
            }
        }

        tdLib.onMessageEdited = { tdMessage ->
            if(tdMessage.chatId == currentChatId) {
                val updated = _messages.value.map { msg ->
                    if(msg.id == tdMessage.id) tdMessage.toChatMessage(myId)
                    else msg
                }
                _messages.value = updated
            }
        }

        tdLib.onMessageDeleted = { chatId, messageId ->
            if(chatId == currentChatId) {
                _messages.value = _messages.value.filter { it.id != messageId }
            }
        }
    }

    private fun TdApi.Message.toChatMessage(myId: Long): ChatMessage {
        val senderId = when(val sender = this.senderId) {
            is TdApi.MessageSenderUser -> sender.userId
            else -> 0
        }
        val text = when(val content = this.content) {
            is TdApi.MessageText -> content.text.text
            is TdApi.MessagePhoto -> content.caption.text.ifEmpty { "📷 Photo" }
            is TdApi.MessageVideo -> content.caption.text.ifEmpty { "🎥 Video" }
            is TdApi.MessageDocument -> content.caption.text.ifEmpty { "📄 ${content.document.fileName}" }
            is TdApi.MessageVoiceNote -> "🎤 Voice message"
            is TdApi.MessageAudio -> "🎵 Audio"
            else -> "Unsupported message"
        }
        val mediaType = when(this.content) {
            is TdApi.MessageText -> MediaType.TEXT
            is TdApi.MessagePhoto -> MediaType.IMAGE
            is TdApi.MessageVideo -> MediaType.VIDEO
            is TdApi.MessageDocument -> MediaType.DOCUMENT
            is TdApi.MessageVoiceNote -> MediaType.VOICE
            is TdApi.MessageAudio -> MediaType.AUDIO
            else -> MediaType.TEXT
        }

        return ChatMessage(
            id = this.id,
            text = text,
            fromMe = senderId == myId,
            timestamp = this.date * 1000L,
            status = if(senderId == myId) MessageStatus.READ else MessageStatus.DELIVERED,
            mediaType = mediaType
        )
    }

    fun loadInitialHistory() {
        if(currentChatId == 0L) return
        _isLoadingHistory.value = true
        tdLib.getChatHistory(currentChatId, fromMessageId = 0, limit = 30) { result ->
            val history = result.messages.map { msg ->
                msg.toChatMessage(myId)
            }.reversed()

            _messages.value = history
            if(history.isNotEmpty()) {
                oldestMessageId = history.firstOrNull()?.id ?: 0
            }
            _hasMoreHistory.value = result.messages.size >= 30
            _isLoadingHistory.value = false
            updateDateSeparators()
        }
    }

    fun loadMoreHistory() {
        if(!_hasMoreHistory.value || _isLoadingHistory.value || currentChatId == 0L || oldestMessageId == 0L) return

        _isLoadingHistory.value = true
        tdLib.getChatHistory(currentChatId, fromMessageId = oldestMessageId, offset = 0, limit = 30) { result ->
            if(result.messages.isEmpty()) {
                _hasMoreHistory.value = false
            } else {
                val moreHistory = result.messages.map { msg -> msg.toChatMessage(myId) }.reversed()
                _messages.value = moreHistory + _messages.value
                oldestMessageId = moreHistory.firstOrNull()?.id ?: oldestMessageId
                _hasMoreHistory.value = result.messages.size >= 30
                updateDateSeparators()
            }
            _isLoadingHistory.value = false
        }
    }

    private fun updateDateSeparators() {
        val separators = mutableMapOf<Long, String>()
        var lastDate = ""
        _messages.value.forEach { msg ->
            val date = java.text.SimpleDateFormat("MMM dd, yyyy").format(java.util.Date(msg.timestamp))
            if(date != lastDate) {
                separators[msg.id] = date
                lastDate = date
            }
        }
        _dateSeparators.value = separators
    }

    fun sendMessage(text: String, replyTo: Long = 0) {
        if(currentChatId == 0L || text.isBlank()) return

        val tempMsg = ChatMessage(
            id = System.currentTimeMillis(),
            text = text,
            fromMe = true,
            timestamp = System.currentTimeMillis(),
            status = MessageStatus.SENDING
        )
        _messages.value = _messages.value + tempMsg

        tdLib.sendMessage(currentChatId, text, replyTo) { sent ->
            // Replace temp with real
            _messages.value = _messages.value.map { msg ->
                if(msg.id == tempMsg.id) sent.toChatMessage(myId).copy(status = MessageStatus.SENT)
                else msg
            }
        }
    }

    fun editMessage(messageId: Long, newText: String) {
        if(currentChatId == 0L) return
        tdLib.editMessage(currentChatId, messageId, newText) { edited ->
            _messages.value = _messages.value.map { msg ->
                if(msg.id == messageId) edited.toChatMessage(myId)
                else msg
            }
        }
    }

    fun deleteMessage(messageId: Long, forBoth: Boolean = true) {
        if(currentChatId == 0L) return
        tdLib.deleteMessage(currentChatId, messageId, forBoth) {
            _messages.value = _messages.value.filter { it.id != messageId }
        }
    }

    fun markAsRead(chatId: Long, messageId: Long) {
        // TDLib automatically handles read via ViewMessages
    }

    fun scrollToMessage(messageId: Long): Int {
        // Return index for LazyColumn scroll
        return _messages.value.indexOfFirst { it.id == messageId }
    }

    fun searchMessages(query: String): List<ChatMessage> {
        return _messages.value.filter { it.text.contains(query, ignoreCase = true) }
    }

    fun retryFailedMessage(messageId: Long) {
        val msg = _messages.value.find { it.id == messageId }
        msg?.let {
            if(it.status == MessageStatus.FAILED) {
                sendMessage(it.text)
                _messages.value = _messages.value.filter { m -> m.id != messageId }
            }
        }
    }
}
