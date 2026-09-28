package com.schatz.production.models

import org.drinkless.tdlib.TdApi

data class ChatMessage(val id: Long, val text: String, val fromMe: Boolean, val timestamp: Long, val status: MessageStatus, val mediaType: MediaType? = null)

enum class MessageStatus { SENDING, SENT, DELIVERED, READ, FAILED }
enum class MediaType { TEXT, IMAGE, VIDEO, DOCUMENT, VOICE, AUDIO }
