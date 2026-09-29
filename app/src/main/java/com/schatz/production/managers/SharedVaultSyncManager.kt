package com.schatz.production.managers

import android.content.Context
import android.util.Log
import org.drinkless.tdlib.TdApi
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class SyncState { SYNCED, SYNCING, FAILED, OFFLINE }

data class SharedVaultFile(
    val id: String,
    val name: String,
    val size: Long,
    val path: String,
    val type: VaultManager.VaultType,
    val ownerId: Long,
    val sharedWithId: Long,
    val timestamp: Long,
    val syncState: SyncState,
    val messageId: Long = 0 // TDLib message id for sync
)

// Shared storage between the two users.
// Transport = the existing TDLib private chat (document message with a
// [SHARED_VAULT] caption). Ownership/sharing relationships are persisted in
// vault_shared/manifest.txt so they survive restarts and sessions.
class SharedVaultSyncManager(private val context: Context, private val tdLib: TdLibUpdateManager, private val vaultManager: VaultManager) {
    companion object { private const val TAG = "SchatzSharedVault" }

    private val _files = MutableStateFlow<List<SharedVaultFile>>(emptyList())
    val files: StateFlow<List<SharedVaultFile>> = _files

    private val _syncState = MutableStateFlow(SyncState.SYNCED)
    val syncState: StateFlow<SyncState> = _syncState

    private val lock = Any()
    private var entries: List<SharedVaultCodec.Entry> = emptyList()

    private var currentChatId: Long = 0
    private var myId: Long = 0
    private var partnerId: Long = 0
    private var listenersRegistered = false

    // Scoped per account so one signed-in user cannot inherit another's shared vault from disk.
    private fun sharedDir(): File = File(context.filesDir, "vault_shared_$myId").apply { mkdirs() }
    private fun manifestFile(): File = File(sharedDir(), MANIFEST_NAME)

    // Ownership metadata. It is never a user-visible file and never a delete target.
    private val MANIFEST_NAME = "manifest.txt"

    fun init(myId: Long, chatId: Long, partnerId: Long = 0L) {
        synchronized(lock) {
            this.myId = myId
            this.currentChatId = chatId
            this.partnerId = partnerId
            loadManifestLocked()
        }
        publishFiles()
        if(!listenersRegistered) {
            tdLib.addNewMessageListener { message -> onSharedVaultMessage(message) }
            tdLib.addMessageDeletedListener { chat, messageId -> onSharedVaultMessageDeleted(chat, messageId) }
            listenersRegistered = true
        }
        syncNow()
    }

    // ---------------------------------------------------------------- persistence

    private fun loadManifestLocked() {
        val file = manifestFile()
        if(!file.exists()) {
            // First run of this implementation: adopt files written by the old
            // local-only shared directory. They were received from the partner
            // over the private chat, so attribute them to the partner (never
            // claim ownership of something that was not explicitly shared by me).
            entries = if(partnerId != 0L && myId != 0L) {
                sharedDir().listFiles()?.filter { it.isFile && it.name != file.name }?.map { f ->
                    SharedVaultCodec.Entry(
                        id = SharedVaultCodec.entryId(partnerId, f.name),
                        name = f.name,
                        ownerId = partnerId,
                        sharedWithId = myId,
                        timestamp = f.lastModified(),
                        messageId = 0L
                    )
                } ?: emptyList()
            } else emptyList()
            if(entries.isNotEmpty()) saveManifestLocked()
            return
        }
        entries = SharedVaultCodec.decodeManifest(try { file.readText() } catch (e: Exception) { "" })
    }

    private fun saveManifestLocked() {
        try { manifestFile().writeText(SharedVaultCodec.encodeManifest(entries)) }
        catch (e: Exception) { Log.e(TAG, "Failed to persist shared vault manifest", e) }
    }

    private fun publishFiles() {
        val dir = sharedDir()
        val snapshot = synchronized(lock) {
            entries
                .filter { SharedVaultCodec.canAccess(it.ownerId, it.sharedWithId, myId) }
                .filter { File(dir, it.name).exists() }
                .sortedByDescending { it.timestamp }
                .map { e ->
                    val f = File(dir, e.name)
                    SharedVaultFile(
                        id = e.id,
                        name = e.name,
                        size = f.length(),
                        path = f.absolutePath,
                        type = getType(e.name),
                        ownerId = e.ownerId,
                        sharedWithId = e.sharedWithId,
                        timestamp = e.timestamp,
                        syncState = SyncState.SYNCED,
                        messageId = e.messageId
                    )
                }
        }
        _files.value = snapshot
    }

    private fun upsert(entry: SharedVaultCodec.Entry) {
        synchronized(lock) {
            entries = entries.filterNot { it.id == entry.id } + entry
            saveManifestLocked()
        }
        publishFiles()
    }

    // ---------------------------------------------------------------- receiving

    private fun onSharedVaultMessage(message: TdApi.Message) {
        if(currentChatId == 0L || message.chatId != currentChatId) return
        val sender = senderIdOf(message) ?: return
        if(!isAllowedSender(sender)) return
        val caption = captionOf(message.content) ?: return
        val meta = SharedVaultCodec.parseCaption(caption) ?: return // ordinary chat message

        // Only the intended recipient may store the item.
        if(sender == myId) {
            if(meta.sharedWithId != 0L && partnerId != 0L && meta.sharedWithId != partnerId) return
        } else {
            if(meta.sharedWithId != 0L && meta.sharedWithId != myId) return
        }

        val name = SharedVaultCodec.sanitizeName(meta.name)
        val id = SharedVaultCodec.entryId(sender, name)
        val dest = File(sharedDir(), name)
        synchronized(lock) {
            if(entries.any { it.id == id } && dest.exists()) return // already have it
        }
        val tdFile = fileOf(message.content) ?: return
        receiveFile(tdFile, id, name, sender, message, meta)
    }

    private fun isAllowedSender(sender: Long): Boolean {
        if(sender == myId) return true
        if(partnerId != 0L && sender == partnerId) return true
        Log.w(TAG, "Ignoring shared vault message from unexpected sender $sender")
        return false
    }

    private fun receiveFile(tdFile: TdApi.File, id: String, name: String, ownerId: Long, message: TdApi.Message, meta: SharedVaultCodec.ShareMeta) {
        _syncState.value = SyncState.SYNCING
        // onComplete fires only once the transfer actually finishes, so an in-flight download is no
        // longer reported as a failure and abandoned.
        tdLib.downloadFile(
            tdFile.id, 32,
            onProgress = { _syncState.value = SyncState.SYNCING },
            onComplete = { downloaded ->
                val localPath = downloaded.local?.path
                if(downloaded.local?.isDownloadingCompleted != true || localPath.isNullOrEmpty()) {
                    Log.e(TAG, "Shared vault download incomplete for $name")
                    _syncState.value = SyncState.FAILED
                    return@downloadFile
                }
                val dest = File(sharedDir(), name)
                try { File(localPath).copyTo(dest, overwrite = true) }
                catch (e: Exception) {
                    Log.e(TAG, "Failed to store shared vault file $name", e)
                    _syncState.value = SyncState.FAILED
                    return@downloadFile
                }
                upsert(SharedVaultCodec.Entry(
                    id = id,
                    name = name,
                    ownerId = ownerId,
                    sharedWithId = myId,
                    timestamp = if(meta.timestamp != 0L) meta.timestamp else message.date * 1000L,
                    messageId = message.id
                ))
                _syncState.value = SyncState.SYNCED
            }
        )
    }

    // Owner deleted the message => access revoked for both sides.
    private fun onSharedVaultMessageDeleted(chatId: Long, messageId: Long) {
        if(currentChatId == 0L || chatId != currentChatId || messageId == 0L) return
        synchronized(lock) {
            val remaining = entries.filterNot { it.messageId == messageId }
            if(remaining.size == entries.size) return
            entries = remaining
            saveManifestLocked()
        }
        publishFiles()
    }

    // ---------------------------------------------------------------- sharing

    // Explicit share: copies the file into the shared store and sends it to the
    // partner over TDLib with ownership metadata. Never called automatically -
    // private vault content only reaches the shared store through this call.
    fun uploadToShared(file: File, onProgress: (Int) -> Unit = {}, onComplete: () -> Unit = {}, onError: (String) -> Unit = {}) {
        if(currentChatId == 0L) { onError("Not connected to private chat"); return }
        if(partnerId == 0L) { onError("No partner linked"); return }
        if(!file.exists()) { onError("File not found"); return }

        _syncState.value = SyncState.SYNCING
        val name = SharedVaultCodec.sanitizeName(file.name)
        val dest = File(sharedDir(), name)
        try {
            if(file.absolutePath != dest.absolutePath) file.copyTo(dest, overwrite = true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stage shared vault file $name", e)
            _syncState.value = SyncState.FAILED
            onError("Could not copy file")
            return
        }

        val caption = SharedVaultCodec.buildCaption(name, partnerId, System.currentTimeMillis())
        tdLib.sendFile(currentChatId, file.absolutePath, caption) { message ->
            upsert(SharedVaultCodec.Entry(
                id = SharedVaultCodec.entryId(myId, name),
                name = name,
                ownerId = myId,
                sharedWithId = partnerId,
                timestamp = System.currentTimeMillis(),
                messageId = message.id
            ))
            _syncState.value = SyncState.SYNCED
            onComplete()
        }
    }

    // Share selected private vault files with the partner. The private copies
    // stay in the private vault - sharing is additive, never a move.
    fun sharePersonalFiles(fileIds: List<String>, onComplete: (Int, String?) -> Unit = { _, _ -> }) {
        if(fileIds.isEmpty()) { onComplete(0, null); return }
        if(currentChatId == 0L || partnerId == 0L) {
            _syncState.value = SyncState.OFFLINE
            onComplete(0, "Shared vault is not ready")
            return
        }
        val sources = fileIds.mapNotNull { id -> vaultManager.personalFiles.value.find { it.id == id } }
        if(sources.isEmpty()) { onComplete(0, "No files selected"); return }

        var shared = 0
        var failed = 0
        var remaining = sources.size
        fun finish() {
            _syncState.value = if(failed == 0) SyncState.SYNCED else SyncState.FAILED
            onComplete(shared, if(failed == 0) null else "$failed file(s) could not be shared")
        }
        sources.forEach { source ->
            uploadToShared(
                file = File(source.path),
                onComplete = { shared += 1; remaining -= 1; if(remaining == 0) finish() },
                onError = { failed += 1; remaining -= 1; if(remaining == 0) finish() }
            )
        }
    }

    // ---------------------------------------------------------------- maintenance

    fun deleteFromShared(fileId: String, onComplete: () -> Unit = {}) {
        val entry = synchronized(lock) { entries.find { it.id == fileId } }
        if(entry == null) { onComplete(); return }

        // Gated on the same access rule that decides visibility, so an id that canAccess() would
        // hide cannot still be used to destroy the other user's bytes.
        if(!SharedVaultCodec.canAccess(entry.ownerId, entry.sharedWithId, myId)) { onComplete(); return }
        if(entry.name == MANIFEST_NAME) { onComplete(); return }

        File(sharedDir(), entry.name).delete()
        val iOwnIt = entry.ownerId == myId
        synchronized(lock) {
            entries = entries.filterNot { it.id == fileId }
            saveManifestLocked()
        }
        publishFiles()

        // Owner revokes for both sides; a recipient only clears their own copy.
        if(iOwnIt && entry.messageId != 0L && currentChatId != 0L) {
            tdLib.deleteMessage(currentChatId, entry.messageId, true) { onComplete() }
        } else {
            onComplete()
        }
    }

    fun renameInShared(fileId: String, newName: String, onComplete: () -> Unit = {}) {
        val entry = synchronized(lock) { entries.find { it.id == fileId } }
        // Previously an unknown id returned without ever calling onComplete, leaving any caller
        // awaiting the callback hanging forever.
        if(entry == null) { onComplete(); return }
        if(!SharedVaultCodec.canAccess(entry.ownerId, entry.sharedWithId, myId)) { onComplete(); return }
        val clean = SharedVaultCodec.sanitizeName(newName)
        if(clean == MANIFEST_NAME) { onComplete(); return }
        val oldFile = File(sharedDir(), entry.name)
        val newFile = File(sharedDir(), clean)
        if(!oldFile.renameTo(newFile)) { onComplete(); return }
        upsert(entry.copy(id = SharedVaultCodec.entryId(entry.ownerId, clean), name = clean))
        onComplete()
    }

    fun syncNow() {
        if(currentChatId == 0L) {
            publishFiles()
            _syncState.value = SyncState.OFFLINE
            return
        }
        _syncState.value = SyncState.SYNCING
        publishFiles()
        // Re-scan chat history so items shared while this device was offline
        // are still downloaded and recorded on the next session.
        tdLib.getChatHistory(currentChatId, limit = 100) { result ->
            result.messages.forEach { onSharedVaultMessage(it) }
            _syncState.value = SyncState.SYNCED
        }
    }

    // ---------------------------------------------------------------- TDLib helpers

    private fun senderIdOf(message: TdApi.Message): Long? = when(val sender = message.senderId) {
        is TdApi.MessageSenderUser -> sender.userId
        else -> null
    }

    private fun captionOf(content: TdApi.MessageContent?): String? = when(content) {
        is TdApi.MessageDocument -> content.caption.text
        is TdApi.MessagePhoto -> content.caption.text
        is TdApi.MessageVideo -> content.caption.text
        else -> null
    }

    private fun fileOf(content: TdApi.MessageContent?): TdApi.File? = when(content) {
        is TdApi.MessageDocument -> content.document.document
        is TdApi.MessagePhoto -> content.photo.sizes.lastOrNull()?.photo
        is TdApi.MessageVideo -> content.video.video
        else -> null
    }

    private fun getType(name: String): VaultManager.VaultType {
        val ext = name.substringAfterLast('.', "").lowercase()
        return when(ext) {
            "jpg","jpeg","png","webp" -> VaultManager.VaultType.IMAGE
            "mp4","mov","avi","mkv" -> VaultManager.VaultType.VIDEO
            "pdf","doc","docx","xls","xlsx","txt" -> VaultManager.VaultType.DOCUMENT
            else -> VaultManager.VaultType.OTHER
        }
    }
}
