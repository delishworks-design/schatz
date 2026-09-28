package com.schatz.production.managers

import android.content.Context
import org.drinkless.tdlib.TdApi
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class FileTransfer(
    val fileId: Int,
    val fileName: String,
    val fileSize: Long,
    val localPath: String,
    val remoteId: String = "",
    val progress: Int = 0, // 0-100
    val isUpload: Boolean,
    val isCompleted: Boolean = false,
    val isFailed: Boolean = false,
    val error: String? = null
)

class FileManager(private val context: Context, private val tdLib: TdLibUpdateManager) {
    private val _uploads = MutableStateFlow<Map<Int, FileTransfer>>(emptyMap())
    val uploads: StateFlow<Map<Int, FileTransfer>> = _uploads

    private val _downloads = MutableStateFlow<Map<Int, FileTransfer>>(emptyMap())
    val downloads: StateFlow<Map<Int, FileTransfer>> = _downloads

    private val _activeTransfers = MutableStateFlow<List<FileTransfer>>(emptyList())
    val activeTransfers: StateFlow<List<FileTransfer>> = _activeTransfers

    init {
        // Listen to file updates from central Update Manager
        tdLib.onFileUpdate = { file ->
            updateTransferProgress(file)
        }
    }

    private fun updateTransferProgress(file: TdApi.File) {
        // Update upload progress
        _uploads.value[file.id]?.let { transfer ->
            val progress = if(file.local?.isDownloadingCompleted == true || file.remote?.isUploadingCompleted == true) 100
            else {
                val downloaded = file.local?.downloadedSize ?: file.remote?.uploadedSize ?: 0
                val expected = file.expectedSize
                if(expected > 0) (downloaded * 100 / expected).toInt() else 0
            }

            val updated = transfer.copy(
                progress = progress,
                isCompleted = progress == 100,
                localPath = file.local?.path ?: transfer.localPath
            )

            val current = _uploads.value.toMutableMap()
            current[file.id] = updated
            _uploads.value = current
            updateActiveTransfers()
        }

        // Update download progress
        _downloads.value[file.id]?.let { transfer ->
            val progress = if(file.local?.isDownloadingCompleted == true) 100
            else {
                val downloaded = file.local?.downloadedSize ?: 0
                val expected = file.expectedSize
                if(expected > 0) (downloaded * 100 / expected).toInt() else 0
            }

            val updated = transfer.copy(
                progress = progress,
                isCompleted = file.local?.isDownloadingCompleted == true,
                localPath = file.local?.path ?: transfer.localPath
            )

            val current = _downloads.value.toMutableMap()
            current[file.id] = updated
            _downloads.value = current
            updateActiveTransfers()
        }
    }

    private fun updateActiveTransfers() {
        val active = mutableListOf<FileTransfer>()
        active.addAll(_uploads.value.values.filter { !it.isCompleted && !it.isFailed })
        active.addAll(_downloads.value.values.filter { !it.isCompleted && !it.isFailed })
        _activeTransfers.value = active
    }

    fun uploadFile(chatId: Long, filePath: String, caption: String = "", onProgress: (Int)->Unit = {}, onComplete: (TdApi.Message)->Unit = {}, onError: (String)->Unit = {}) {
        val file = File(filePath)
        if(!file.exists()) {
            onError("File not found")
            return
        }

        val fileId = file.hashCode() // temporary
        val transfer = FileTransfer(
            fileId = fileId,
            fileName = file.name,
            fileSize = file.length(),
            localPath = filePath,
            progress = 0,
            isUpload = true
        )

        val current = _uploads.value.toMutableMap()
        current[fileId] = transfer
        _uploads.value = current

        // Use TDLib to send file - it will handle upload via UpdateFile
        when {
            file.extension.lowercase() in listOf("jpg","jpeg","png","webp") -> {
                tdLib.sendPhoto(chatId, filePath, caption) { msg ->
                    // Extract file id from message
                    val content = msg.content
                    val tdFile = when(content) {
                        is TdApi.MessagePhoto -> content.photo.sizes.lastOrNull()?.photo
                        is TdApi.MessageDocument -> content.document.document
                        else -> null
                    }
                    tdFile?.let {
                        // Update with real file id
                        val realTransfer = transfer.copy(fileId = it.id)
                        val updated = _uploads.value.toMutableMap()
                        updated.remove(fileId)
                        updated[it.id] = realTransfer
                        _uploads.value = updated
                    }
                    onComplete(msg)
                }
            }
            file.extension.lowercase() in listOf("mp4","mov","avi","mkv") -> {
                tdLib.sendVideo(chatId, filePath, caption) { msg -> onComplete(msg) }
            }
            else -> {
                tdLib.sendFile(chatId, filePath, caption) { msg -> onComplete(msg) }
            }
        }
    }

    fun downloadFile(fileId: Int, fileName: String, onProgress: (Int)->Unit = {}, onComplete: (String)->Unit = {}, onError: (String)->Unit = {}) {
        val transfer = FileTransfer(
            fileId = fileId,
            fileName = fileName,
            fileSize = 0,
            localPath = "",
            progress = 0,
            isUpload = false
        )

        val current = _downloads.value.toMutableMap()
        current[fileId] = transfer
        _downloads.value = current

        tdLib.downloadFile(fileId, 32) { file ->
            if(file.local?.isDownloadingCompleted == true) {
                val updated = _downloads.value.toMutableMap()
                updated[fileId] = transfer.copy(localPath = file.local.path, progress = 100, isCompleted = true)
                _downloads.value = updated
                onComplete(file.local.path)
            }
        }
    }

    fun cancelUpload(fileId: Int) {
        tdLib.cancelUpload(fileId)
        val current = _uploads.value.toMutableMap()
        current.remove(fileId)
        _uploads.value = current
        updateActiveTransfers()
    }

    fun cancelDownload(fileId: Int) {
        tdLib.cancelDownload(fileId)
        val current = _downloads.value.toMutableMap()
        current.remove(fileId)
        _downloads.value = current
        updateActiveTransfers()
    }

    fun retryUpload(transfer: FileTransfer, chatId: Long) {
        uploadFile(chatId, transfer.localPath)
    }

    fun retryDownload(transfer: FileTransfer) {
        downloadFile(transfer.fileId, transfer.fileName)
    }

    fun getFilePreview(fileId: Int, callback: (String)->Unit) {
        // Get file path for preview
        tdLib.downloadFile(fileId, 1) { file ->
            if(file.local?.path?.isNotEmpty() == true) {
                callback(file.local.path)
            }
        }
    }

    fun clearCompleted() {
        _uploads.value = _uploads.value.filter { !it.value.isCompleted }.toMap()
        _downloads.value = _downloads.value.filter { !it.value.isCompleted }.toMap()
    }
}
