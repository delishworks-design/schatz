package com.schatz.production.managers

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject

enum class CallType { INCOMING, OUTGOING, MISSED, DECLINED, FAILED }
enum class CallMedia { AUDIO, VIDEO }

data class CallHistoryItem(
    val id: String,
    val partnerId: Long,
    val partnerName: String,
    val type: CallType,
    val media: CallMedia,
    val timestamp: Long,
    val duration: Long, // seconds, 0 if missed/failed
    val isFromMe: Boolean
)

class CallHistoryManager(context: Context) {
    private val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
    private val prefs = EncryptedSharedPreferences.create(
        context, "schatz_call_history", masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val _history = MutableStateFlow<List<CallHistoryItem>>(emptyList())
    val history: StateFlow<List<CallHistoryItem>> = _history

    init {
        loadHistory()
    }

    private fun loadHistory() {
        val json = prefs.getString("history", "[]") ?: "[]"
        try {
            val array = JSONArray(json)
            val list = mutableListOf<CallHistoryItem>()
            for(i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                list.add(CallHistoryItem(
                    id = obj.getString("id"),
                    partnerId = obj.getLong("partnerId"),
                    partnerName = obj.getString("partnerName"),
                    type = CallType.valueOf(obj.getString("type")),
                    media = CallMedia.valueOf(obj.getString("media")),
                    timestamp = obj.getLong("timestamp"),
                    duration = obj.getLong("duration"),
                    isFromMe = obj.getBoolean("isFromMe")
                ))
            }
            _history.value = list.sortedByDescending { it.timestamp }
        } catch(e: Exception) {
            _history.value = emptyList()
        }
    }

    private fun saveHistory() {
        val array = JSONArray()
        _history.value.forEach { item ->
            val obj = JSONObject().apply {
                put("id", item.id)
                put("partnerId", item.partnerId)
                put("partnerName", item.partnerName)
                put("type", item.type.name)
                put("media", item.media.name)
                put("timestamp", item.timestamp)
                put("duration", item.duration)
                put("isFromMe", item.isFromMe)
            }
            array.put(obj)
        }
        prefs.edit().putString("history", array.toString()).apply()
    }

    fun addCall(item: CallHistoryItem) {
        val current = _history.value.toMutableList()
        current.add(0, item)
        // Keep only last 100 calls
        if(current.size > 100) current.removeAt(current.size - 1)
        _history.value = current
        saveHistory()
    }

    fun addFromCallState(callState: CallState, partnerId: Long, partnerName: String, media: CallMedia, duration: Long, isFromMe: Boolean) {
        val type = when(callState) {
            CallState.CALLING, CallState.CONNECTING, CallState.CONNECTED -> if(isFromMe) CallType.OUTGOING else CallType.INCOMING
            CallState.MISSED -> CallType.MISSED
            CallState.DECLINED -> CallType.DECLINED
            CallState.FAILED, CallState.BUSY -> CallType.FAILED
            else -> if(isFromMe) CallType.OUTGOING else CallType.INCOMING
        }
        // Only save if ended, missed, declined, failed
        if(callState == CallState.ENDED || callState == CallState.MISSED || callState == CallState.DECLINED || callState == CallState.FAILED) {
            addCall(CallHistoryItem(
                id = System.currentTimeMillis().toString(),
                partnerId = partnerId,
                partnerName = partnerName,
                type = type,
                media = media,
                timestamp = System.currentTimeMillis(),
                duration = if(type == CallType.MISSED || type == CallType.FAILED) 0 else duration,
                isFromMe = isFromMe
            ))
        }
    }

    fun clearHistory() {
        _history.value = emptyList()
        prefs.edit().remove("history").apply()
    }

    fun getHistoryForPartner(partnerId: Long): List<CallHistoryItem> {
        return _history.value.filter { it.partnerId == partnerId }
    }
}
