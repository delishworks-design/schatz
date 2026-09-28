package com.schatz.production.managers

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

fun saveToDownloads(context: Context, source: File): Boolean {
    if(!source.exists()) return false
    val name = source.name
    return try {
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase()) ?: "application/octet-stream"
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return false
            val out = context.contentResolver.openOutputStream(uri) ?: return false
            out.use { sink -> source.inputStream().use { it.copyTo(sink) } }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
            true
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if(!dir.exists() && !dir.mkdirs()) return false
            val dest = File(dir, name)
            source.copyTo(dest, overwrite = true)
            MediaScannerConnection.scanFile(context, arrayOf(dest.absolutePath), null, null)
            true
        }
    } catch(e: Exception) {
        false
    }
}

class VaultManager(private val context: Context) {
    data class VaultFile(val id: String, val name: String, val size: Long, val path: String, val type: VaultType, val ownerId: Long, val isShared: Boolean, val timestamp: Long)
    enum class VaultType { IMAGE, VIDEO, DOCUMENT, OTHER }

    private val _personalFiles = MutableStateFlow<List<VaultFile>>(emptyList())
    val personalFiles: StateFlow<List<VaultFile>> = _personalFiles
    private val _sharedFiles = MutableStateFlow<List<VaultFile>>(emptyList())
    val sharedFiles: StateFlow<List<VaultFile>> = _sharedFiles

    private fun getPersonalDir(userId: Long): File { return File(context.filesDir, "vault_personal_$userId").apply { mkdirs() } }
    private fun getSharedDir(): File { return File(context.filesDir, "vault_shared").apply { mkdirs() } }

    fun loadVaults(myId: Long) {
        val personalDir = getPersonalDir(myId)
        val personal = personalDir.listFiles()?.map { file ->
            VaultFile(file.name, file.name, file.length(), file.absolutePath, getType(file.name), myId, false, file.lastModified())
        } ?: emptyList()
        _personalFiles.value = personal
        val sharedDir = getSharedDir()
        val shared = sharedDir.listFiles()?.map { file ->
            VaultFile(file.name, file.name, file.length(), file.absolutePath, getType(file.name), 0, true, file.lastModified())
        } ?: emptyList()
        _sharedFiles.value = shared
    }

    fun uploadToPersonal(file: File, myId: Long) {
        val dest = File(getPersonalDir(myId), file.name)
        file.copyTo(dest, overwrite = true)
        loadVaults(myId)
    }

    fun deletePersonal(fileId: String, myId: Long) {
        val file = File(getPersonalDir(myId), fileId)
        if(file.exists()) file.delete()
        loadVaults(myId)
    }

    fun deleteShared(fileId: String) {
        val file = File(getSharedDir(), fileId)
        if(file.exists()) file.delete()
        _sharedFiles.value = _sharedFiles.value.filter { it.id != fileId }
    }

    private fun getType(name: String): VaultType {
        val ext = name.substringAfterLast('.', "").lowercase()
        return when(ext) {
            "jpg","jpeg","png","webp" -> VaultType.IMAGE
            "mp4","mov","avi","mkv" -> VaultType.VIDEO
            "pdf","doc","docx","xls","xlsx","txt" -> VaultType.DOCUMENT
            else -> VaultType.OTHER
        }
    }

    fun getStorageUsage(myId: Long): Long {
        val personalSize = getPersonalDir(myId).listFiles()?.sumOf { it.length() } ?: 0
        val sharedSize = getSharedDir().listFiles()?.sumOf { it.length() } ?: 0
        return personalSize + sharedSize
    }
}
