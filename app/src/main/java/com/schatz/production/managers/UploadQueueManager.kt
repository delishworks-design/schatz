package com.schatz.production.managers
import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
data class QueuedUpload(val id: String, val filePath: String, val fileName: String, val chatId: Long, val caption: String, val isSharedVault: Boolean, val retryCount: Int=0)
class UploadQueueManager(private val context: Context) {
    private val masterKey=MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
    private val prefs=EncryptedSharedPreferences.create(context, "schatz_upload_queue", masterKey, EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV, EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)
    fun addToQueue(upload: QueuedUpload) { val cur=getQueue().toMutableList(); cur.add(upload); saveQueue(cur) }
    fun getQueue(): List<QueuedUpload> { val json=prefs.getString("queue","[]")?:"[]"; return try{val arr=JSONArray(json); val list=mutableListOf<QueuedUpload>(); for(i in 0 until arr.length()){val obj=arr.getJSONObject(i); list.add(QueuedUpload(obj.getString("id"), obj.getString("filePath"), obj.getString("fileName"), obj.getLong("chatId"), obj.getString("caption"), obj.getBoolean("isSharedVault"), obj.optInt("retryCount",0)))}; list}catch(e:Exception){emptyList()} }
    fun removeFromQueue(id: String) { saveQueue(getQueue().filter{it.id!=id}) }
    private fun saveQueue(queue: List<QueuedUpload>) { val arr=JSONArray(); queue.forEach{val obj=JSONObject().apply{put("id",it.id); put("filePath",it.filePath); put("fileName",it.fileName); put("chatId",it.chatId); put("caption",it.caption); put("isSharedVault",it.isSharedVault); put("retryCount",it.retryCount)}; arr.put(obj)}; prefs.edit().putString("queue", arr.toString()).apply() }
    fun restoreQueue() { getQueue().forEach{val f=File(it.filePath); if(!f.exists()) removeFromQueue(it.id)} }
}
