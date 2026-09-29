package com.schatz.production.models

import org.drinkless.tdlib.TdApi

/**
 * [mediaFileId] is the TDLib file id of an attachment. Without it the UI had no way to fetch the
 * bytes, so a received photo or document could only ever be shown as the text label "Photo".
 *
 * [reactions] mirrors TdApi.MessageInteractionInfo.reactions - this TDLib build carries reactions
 * there rather than as a direct message field.
 *
 * [replyToMessageId]/[replyToPreview] come from TdApi.MessageReplyToMessage (quote), so a sent
 * reply can render the quoted text inside its own bubble.
 */
data class ChatMessage(
    val id: Long,
    val text: String,
    val fromMe: Boolean,
    val timestamp: Long,
    val status: MessageStatus,
    val mediaType: MediaType? = null,
    val mediaFileId: Int = 0,
    val localPath: String? = null,
    val reactions: List<ChatReaction> = emptyList(),
    val replyToMessageId: Long = 0,
    val replyToPreview: String? = null
)

/** One emoji reaction row: how many, and whether the local user has taken it. */
data class ChatReaction(val emoji: String, val count: Int, val isMine: Boolean)

enum class MessageStatus { SENDING, SENT, DELIVERED, READ, FAILED }
enum class MediaType { TEXT, IMAGE, VIDEO, DOCUMENT, VOICE, AUDIO }
