package com.schatz.production.managers

import org.drinkless.tdlib.TdApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import com.schatz.production.models.ChatMessage
import com.schatz.production.models.ChatReaction
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

    // fileId -> absolute local path, filled once TDLib reports the download complete.
    private val _mediaPaths = MutableStateFlow<Map<Int, String>>(emptyMap())
    val mediaPaths: StateFlow<Map<Int, String>> = _mediaPaths

    // fileId -> 0..100 download progress, so a bubble can show a real bar instead of nothing.
    private val _mediaDownloads = MutableStateFlow<Map<Int, Int>>(emptyMap())
    val mediaDownloads: StateFlow<Map<Int, Int>> = _mediaDownloads

    // Files we already asked TDLib about, so history re-mapping never re-requests them.
    private val startedFiles = java.util.concurrent.ConcurrentHashMap.newKeySet<Int>()

    // True while the partner is typing; cleared by ChatActionCancel or a safety timeout.
    private val _partnerTyping = MutableStateFlow(false)
    val partnerTyping: StateFlow<Boolean> = _partnerTyping

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val typingClear = Runnable { _partnerTyping.value = false }

    fun init(myId: Long, chatId: Long) {
        this.myId = myId
        this.currentChatId = chatId
        loadInitialHistory()

        // Listen for new messages via central Update Manager
        tdLib.onNewMessage = { tdMessage ->
            if(tdMessage.chatId == currentChatId) {
                val chatMsg = tdMessage.toChatMessage(myId)
                // TDLib also echoes the user's own outgoing message back as updateNewMessage. The
                // optimistic append in sendMessage plus this append used to produce two bubbles for
                // one message, so upsert by id instead of blindly adding.
                _messages.value = if (_messages.value.any { it.id == chatMsg.id }) {
                    _messages.value.map { if (it.id == chatMsg.id) chatMsg else it }
                } else {
                    _messages.value + chatMsg
                }
                markAsRead(tdMessage.chatId, tdMessage.id)
                syncMediaFiles(listOf(chatMsg))
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

        // A rejected send has to be reflected, otherwise the bubble keeps spinning on SENDING.
        tdLib.onMessageSendFailed = { messageId, reason ->
            _messages.value = _messages.value.map { msg ->
                if (msg.id == messageId) msg.copy(status = MessageStatus.FAILED) else msg
            }
        }

        tdLib.onMessageSendSucceeded = { messageId ->
            _messages.value = _messages.value.map { msg ->
                if (msg.id == messageId && msg.status == MessageStatus.SENDING) msg.copy(status = MessageStatus.SENT) else msg
            }
        }

        tdLib.onMessageDeleted = { chatId, messageId ->
            if(chatId == currentChatId) {
                _messages.value = _messages.value.filter { it.id != messageId }
            }
        }

        // Reaction tallies arrive as their own update; this TDLib build has no reactions field
        // on Message itself, so interaction info is the only source.
        tdLib.onMessageReactions = { chatId, messageId, reactions ->
            if (chatId == currentChatId) applyReactions(messageId, reactions)
        }

        // Partner typing -> show the indicator, then auto-clear (Telegram re-sends every few
        // seconds while the user keeps typing, so the timeout only fires when they stop).
        tdLib.onChatAction = { chatId, senderId, action ->
            if (chatId == currentChatId) {
                val fromPartner = (senderId as? TdApi.MessageSenderUser)?.userId
                if (fromPartner != null && fromPartner != myId) {
                    mainHandler.removeCallbacks(typingClear)
                    if (action is TdApi.ChatActionTyping) {
                        _partnerTyping.value = true
                        mainHandler.postDelayed(typingClear, 6000)
                    } else {
                        _partnerTyping.value = false
                    }
                }
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
            is TdApi.MessageAudio -> "🎵 ${content.audio.title.ifEmpty { "Audio" }}"
            // TDLib posts a service message for every call. Falling through to "Unsupported
            // message" made the chat show that literal text instead of the call outcome, and
            // there was no way to tell a missed call from a corrupted message.
            is TdApi.MessageCall -> callServiceText(content, senderId == myId)
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

        // The TDLib file id of the attachment, so the UI can actually fetch the bytes instead of
        // only ever showing a text placeholder. Audio does carry a File in this TDLib build.
        val mediaFileId = when(val content = this.content) {
            is TdApi.MessagePhoto -> content.photo?.sizes?.lastOrNull()?.photo?.id ?: 0
            is TdApi.MessageVideo -> content.video?.video?.id ?: 0
            is TdApi.MessageDocument -> content.document?.document?.id ?: 0
            is TdApi.MessageVoiceNote -> content.voiceNote?.voice?.id ?: 0
            is TdApi.MessageAudio -> content.audio?.audio?.id ?: 0
            else -> 0
        }

        // Reactions live in interactionInfo on this TDLib version.
        val reactions = this.interactionInfo?.reactions?.reactions
            ?.mapNotNull { r ->
                val emoji = (r.type as? TdApi.ReactionTypeEmoji)?.emoji ?: return@mapNotNull null
                ChatReaction(emoji, r.totalCount, r.isChosen)
            } ?: emptyList()

        // Quoted reply: MessageReplyToMessage carries the id, TextQuote carries the preview text.
        val reply = this.replyTo as? TdApi.MessageReplyToMessage

        return ChatMessage(
            id = this.id,
            text = text,
            fromMe = senderId == myId,
            timestamp = this.date * 1000L,
            // Never claim "read" on the spot. The tick now reflects what TDLib actually reported.
            status = if (senderId == myId) MessageStatus.SENT else MessageStatus.DELIVERED,
            mediaType = mediaType,
            mediaFileId = mediaFileId,
            localPath = _mediaPaths.value[mediaFileId],
            reactions = reactions,
            replyToMessageId = reply?.messageId ?: 0L,
            replyToPreview = reply?.quote?.text?.text
        )
    }

    /**
     * Renders TDLib's call service message. A positive duration means the call connected; the
     * discard reason explains every other outcome.
     */
    private fun callServiceText(content: TdApi.MessageCall, fromMe: Boolean): String {
        val kind = if (content.isVideo) "Video call" else "Call"
        if (content.duration > 0) {
            val mins = content.duration / 60
            val secs = content.duration % 60
            val time = if (mins > 0) "$mins:${secs.toString().padStart(2, '0')}" else "${secs}s"
            return "📞 $time • ${if (fromMe) "Outgoing $kind" else "Incoming $kind"}"
        }
        return when (content.discardReason) {
            is TdApi.CallDiscardReasonMissed -> if (fromMe) "📞 Unanswered $kind" else "📞 Missed $kind"
            is TdApi.CallDiscardReasonDeclined -> "📞 Declined $kind"
            is TdApi.CallDiscardReasonDisconnected -> "📞 ${if (fromMe) "Cancelled" else "Disconnected"}"
            is TdApi.CallDiscardReasonHungUp -> "📞 ${if (fromMe) "Cancelled" else "Hung up"}"
            else -> "📞 ${if (fromMe) "Outgoing" else "Incoming"} $kind"
        }
    }

    private fun applyReactions(messageId: Long, updates: Array<TdApi.MessageReaction>) {
        val reactions = updates.mapNotNull { r ->
            val emoji = (r.type as? TdApi.ReactionTypeEmoji)?.emoji ?: return@mapNotNull null
            ChatReaction(emoji, r.totalCount, r.isChosen)
        }
        _messages.value = _messages.value.map { msg ->
            if (msg.id == messageId) msg.copy(reactions = reactions) else msg
        }
    }

    /**
     * Resolves every attachment in [batch]: already-local files are picked up via GetFile, and
     * incoming photos/voice notes/audio are downloaded automatically. Documents and videos are
     * left for an explicit tap - they are the big ones.
     */
    private fun syncMediaFiles(batch: List<ChatMessage>) {
        batch.filter { it.mediaFileId != 0 && !it.fromMe }.forEach { msg ->
            val fileId = msg.mediaFileId
            if (!startedFiles.add(fileId)) return@forEach
            val auto = msg.mediaType == MediaType.IMAGE || msg.mediaType == MediaType.VOICE || msg.mediaType == MediaType.AUDIO
            tdLib.getFile(fileId) { file ->
                if (file.local?.isDownloadingCompleted == true) {
                    file.local?.path?.let { onFileReady(fileId, it) }
                } else if (auto) {
                    startDownload(fileId)
                } else {
                    startedFiles.remove(fileId) // allow a later tap to try again
                }
            }
        }
    }

    /** Tap-to-download for the heavy types (documents, videos). Safe to call repeatedly. */
    fun downloadMedia(message: ChatMessage) {
        val fileId = message.mediaFileId
        if (fileId == 0) return
        if (_mediaPaths.value.containsKey(fileId)) return
        if (!startedFiles.add(fileId)) return // already in flight
        startDownload(fileId)
    }

    private fun startDownload(fileId: Int) {
        _mediaDownloads.value = _mediaDownloads.value + (fileId to 0)
        tdLib.downloadFile(
            fileId,
            onProgress = { file ->
                val expected = file.expectedSize
                val done = file.local?.downloadedSize ?: 0
                val pct = if (expected > 0) ((done * 100) / expected).toInt() else 0
                _mediaDownloads.value = _mediaDownloads.value + (fileId to pct)
            },
            onComplete = { file ->
                file.local?.path?.let { onFileReady(fileId, it) }
            }
        )
    }

    private fun onFileReady(fileId: Int, path: String) {
        _mediaPaths.value = _mediaPaths.value + (fileId to path)
        _mediaDownloads.value = _mediaDownloads.value - fileId
        // Backfill the path onto every bubble that references this file.
        _messages.value = _messages.value.map { msg ->
            if (msg.mediaFileId == fileId && msg.localPath != path) msg.copy(localPath = path) else msg
        }
    }

    fun loadInitialHistory() {
        if(currentChatId == 0L) return
        _isLoadingHistory.value = true
        tdLib.getChatHistory(currentChatId, fromMessageId = 0, limit = INITIAL_PAGE) { result ->
            val history = result.messages.map { msg ->
                msg.toChatMessage(myId)
            }.reversed()

            _messages.value = history
            if(history.isNotEmpty()) {
                oldestMessageId = history.firstOrNull()?.id ?: 0
            }
            _hasMoreHistory.value = result.messages.size >= INITIAL_PAGE
            _isLoadingHistory.value = false
            updateDateSeparators()
            syncMediaFiles(history)
        }
    }

    fun loadMoreHistory() {
        if(!_hasMoreHistory.value || _isLoadingHistory.value || currentChatId == 0L || oldestMessageId == 0L) return

        _isLoadingHistory.value = true
        tdLib.getChatHistory(currentChatId, fromMessageId = oldestMessageId, offset = 0, limit = INITIAL_PAGE) { result ->
            if(result.messages.isEmpty()) {
                _hasMoreHistory.value = false
            } else {
                val moreHistory = result.messages.map { msg -> msg.toChatMessage(myId) }.reversed()
                _messages.value = moreHistory + _messages.value
                oldestMessageId = moreHistory.firstOrNull()?.id ?: oldestMessageId
                _hasMoreHistory.value = result.messages.size >= INITIAL_PAGE
                updateDateSeparators()
                syncMediaFiles(moreHistory)
            }
            _isLoadingHistory.value = false
        }
    }

    companion object {
        // 30 left older history out of reach after the first screen; 100 matches what a chat
        // actually shows before the user scrolls.
        const val INITIAL_PAGE = 100
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

    /**
     * Sends the read receipt. TDLib does not mark messages read on its own, so the previous empty
     * body meant the peer never saw a read tick. Batched so a burst of messages is one request.
     */
    fun markAsRead(chatId: Long, messageId: Long) {
        synchronized(pendingReads) { pendingReads.add(messageId) }
        flushReads(chatId)
    }

    private val pendingReads = java.util.LinkedHashSet<Long>()

    private fun flushReads(chatId: Long) {
        val batch = synchronized(pendingReads) {
            if (pendingReads.isEmpty()) return
            val ids = pendingReads.toLongArray()
            pendingReads.clear()
            ids
        }
        tdLib.viewMessages(chatId, batch)
    }

    fun scrollToMessage(messageId: Long): Int {
        // Return index for LazyColumn scroll
        return _messages.value.indexOfFirst { it.id == messageId }
    }

    fun searchMessages(query: String): List<ChatMessage> {
        return _messages.value.filter { it.text.contains(query, ignoreCase = true) }
    }

    /**
     * Server-side search (TDLib.SearchChatMessages): finds messages that were never paged in.
     * Results are upserted into the visible list so tapping one can scroll straight to it.
     */
    fun searchRemote(query: String, callback: (List<ChatMessage>) -> Unit) {
        if (currentChatId == 0L) { callback(emptyList()); return }
        tdLib.searchChatMessages(currentChatId, query) { found ->
            val results = found.map { it.toChatMessage(myId) }
            if (results.isNotEmpty()) {
                val known = _messages.value.map { it.id }.toHashSet()
                val missing = results.filterNot { known.contains(it.id) }
                if (missing.isNotEmpty()) {
                    _messages.value = (_messages.value + missing).sortedBy { it.id }
                    updateDateSeparators()
                    syncMediaFiles(missing)
                }
            }
            callback(results)
        }
    }

    /**
     * Index (in the reversed order the LazyColumn renders) of [messageId], loading the page
     * around it first when the target is not in the loaded window. -1 when it cannot be found.
     */
    fun jumpToMessage(messageId: Long, callback: (Int) -> Unit) {
        val visible = _messages.value
        val ascending = visible.indexOfFirst { it.id == messageId }
        if (ascending >= 0) { callback(visible.size - 1 - ascending); return }

        // Fetch a window centred on the target: offset -15 puts the target ~15 rows from the end.
        tdLib.getChatHistory(currentChatId, fromMessageId = messageId, offset = -15, limit = 40) { result ->
            val window = result.messages.map { it.toChatMessage(myId) }
            if (window.isEmpty()) { callback(-1); return@getChatHistory }
            val known = _messages.value.map { it.id }.toHashSet()
            val missing = window.filterNot { known.contains(it.id) }
            if (missing.isNotEmpty()) {
                _messages.value = (_messages.value + missing).sortedBy { it.id }
                updateDateSeparators()
                syncMediaFiles(missing)
            }
            val idx = _messages.value.indexOfFirst { it.id == messageId }
            if (idx >= 0) callback(_messages.value.size - 1 - idx) else callback(-1)
        }
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
