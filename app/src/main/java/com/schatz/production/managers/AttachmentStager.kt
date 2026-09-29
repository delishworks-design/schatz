package com.schatz.production.managers

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream

/**
 * Copies a picked content:// uri into app-private storage and hands back a real path.
 *
 * TdApi.InputFileLocal only accepts an absolute filesystem path, and File(uri) is not one, so
 * every send of a picked file failed with TDLib 400 until the bytes were copied first.
 */
class AttachmentStager(private val context: Context) {

    private val stagedDir: File
        get() = File(context.cacheDir, "staged").apply { mkdirs() }

    data class Staged(val file: File, val displayName: String, val mimeType: String)

    /**
     * Copies the uri into the cache and returns the staged file, or null when the stream cannot be
     * read. The caller owns the returned file for the lifetime of the send.
     */
    fun stage(uri: Uri): Staged? {
        return try {
            val displayName = queryDisplayName(uri) ?: "file"
            val mimeType = context.contentResolver.getType(uri) ?: guessFromName(displayName)
            val target = File(stagedDir, "${System.currentTimeMillis()}_$displayName")

            val copied = context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            }
            if (copied == null) { target.delete(); null } else Staged(target, displayName, mimeType)
        } catch (e: Exception) {
            null
        }
    }

    /** Removes previously staged copies so the cache does not grow without bound. */
    fun clearStaged() {
        try { stagedDir.listFiles()?.forEach { it.delete() } } catch (e: Exception) { }
    }

    private fun queryDisplayName(uri: Uri): String? = try {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    } catch (e: Exception) {
        null
    }

    private fun guessFromName(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "gif" -> "image/gif"
        "mp4", "mov", "mkv", "webm" -> "video/mp4"
        "mp3", "m4a", "ogg", "aac" -> "audio/mpeg"
        "pdf" -> "application/pdf"
        else -> "*/*"
    }

    /** Routes a staged file to the right TDLib sender based on its type. */
    fun send(staged: Staged, chatId: Long, tdLib: TdLibUpdateManager, onDone: (Boolean, String)->Unit) {
        val path = staged.file.absolutePath
        val callback: (org.drinkless.tdlib.TdApi.Message) -> Unit = { onDone(true, it.id.toString()) }
        when {
            staged.mimeType.startsWith("image/") -> tdLib.sendPhoto(chatId, path, staged.displayName, callback)
            staged.mimeType.startsWith("video/") -> tdLib.sendVideo(chatId, path, staged.displayName, callback)
            staged.mimeType.startsWith("audio/") -> tdLib.sendFile(chatId, path, staged.displayName, callback)
            else -> tdLib.sendFile(chatId, path, staged.displayName, callback)
        }
    }
}
