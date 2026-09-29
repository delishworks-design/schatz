package com.schatz.production.managers
import android.content.Context
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
data class VaultFolder(val id: String, val name: String, val path: String, val parentId: String? = null)
data class EnhancedVaultFile(val id: String, val name: String, val size: Long, val path: String, val type: VaultType, val ownerId: Long, val isShared: Boolean, val timestamp: Long, val folderId: String? = null)
enum class VaultType { IMAGE, VIDEO, DOCUMENT, OTHER }
enum class SortBy { NAME, DATE, SIZE }
enum class ViewMode { GRID, LIST }
class EnhancedVaultManager(private val context: Context) {
    private val _personalFiles = MutableStateFlow<List<EnhancedVaultFile>>(emptyList())
    val personalFiles: StateFlow<List<EnhancedVaultFile>> = _personalFiles
    private val _sharedFiles = MutableStateFlow<List<EnhancedVaultFile>>(emptyList())
    val sharedFiles: StateFlow<List<EnhancedVaultFile>> = _sharedFiles
    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery
    private val _sortBy = MutableStateFlow(SortBy.DATE)
    val sortBy: StateFlow<SortBy> = _sortBy
    private val _viewMode = MutableStateFlow(ViewMode.GRID)
    val viewMode: StateFlow<ViewMode> = _viewMode
    private val _storageUsage = MutableStateFlow(0L)
    val storageUsage: StateFlow<Long> = _storageUsage
    private fun getPersonalDir(userId: Long): File { return File(context.filesDir, "vault_personal_$userId").apply { mkdirs() } }

    // The shared store is scoped per account. A single global directory leaked one account's
    // shared vault into the next account that signed in on the device.
    private fun getSharedDir(userId: Long): File { return File(context.filesDir, "vault_shared_$userId").apply { mkdirs() } }

    // Ownership metadata, never user content. Listing it used to expose (and let the user delete)
    // the whole manifest, after which the vault re-adopted every file as owned by the current user.
    private val MANIFEST_NAME = "manifest.txt"

    fun loadVaults(myId: Long) {
        val personalDir = getPersonalDir(myId)
        val personal = personalDir.walkTopDown().filter { it.isFile && it.name != MANIFEST_NAME }
            .map { f -> EnhancedVaultFile(f.name, f.name, f.length(), f.absolutePath, getType(f.name), myId, false, f.lastModified()) }.toList()
        _personalFiles.value = applySortAndFilter(personal, _searchQuery.value, _sortBy.value)
        val sharedDir = getSharedDir(myId)
        val shared = sharedDir.walkTopDown().filter { it.isFile && it.name != MANIFEST_NAME }
            .map { f -> EnhancedVaultFile(f.name, f.name, f.length(), f.absolutePath, getType(f.name), 0, true, f.lastModified()) }.toList()
        _sharedFiles.value = applySortAndFilter(shared, _searchQuery.value, _sortBy.value)
        updateStorageUsage(myId)
    }
    private fun applySortAndFilter(files: List<EnhancedVaultFile>, query: String, sort: SortBy): List<EnhancedVaultFile> {
        var filtered = if(query.isBlank()) files else files.filter { it.name.contains(query, ignoreCase=true) }
        return when(sort) {
            SortBy.NAME -> filtered.sortedBy { it.name.lowercase() }
            SortBy.DATE -> filtered.sortedByDescending { it.timestamp }
            SortBy.SIZE -> filtered.sortedByDescending { it.size }
        }
    }
    fun setSearchQuery(query: String, myId: Long) { _searchQuery.value = query; loadVaults(myId) }
    fun setSortBy(sort: SortBy, myId: Long) { _sortBy.value = sort; loadVaults(myId) }
    fun setViewMode(mode: ViewMode) { _viewMode.value = mode }
    fun createFolder(name: String, isShared: Boolean, myId: Long): File { val baseDir = if(isShared) getSharedDir(myId) else getPersonalDir(myId); return File(baseDir, name).apply { mkdirs() }.also { loadVaults(myId) } }
    fun moveFile(fileId: String, targetFolder: String?, isShared: Boolean, myId: Long) { val baseDir = if(isShared) getSharedDir(myId) else getPersonalDir(myId); val file = if(isShared) _sharedFiles.value.find { it.id==fileId } else _personalFiles.value.find { it.id==fileId }; file?.let { val src=File(it.path); val dst=File(if(targetFolder!=null) File(baseDir, targetFolder) else baseDir, src.name); if(src.renameTo(dst)) loadVaults(myId) } }
    /**
     * Only deletes files this account is allowed to touch. Ownership metadata is never a
     * deletable target, and the delete is confined to the caller's own vault directory.
     */
    fun deleteFile(fileId: String, isShared: Boolean, myId: Long) {
        val file = if(isShared) _sharedFiles.value.find { it.id==fileId } else _personalFiles.value.find { it.id==fileId }
        if(file == null) return
        if(file.name == MANIFEST_NAME) return
        val allowedRoot = if(isShared) getSharedDir(myId) else getPersonalDir(myId)
        val target = File(file.path).canonicalFile
        if(!target.path.startsWith(allowedRoot.canonicalFile.path + File.separator)) return
        target.delete()
        loadVaults(myId)
    }
    fun getStorageUsageFormatted(myId: Long): String { updateStorageUsage(myId); val b=_storageUsage.value; return when { b>=1024*1024*1024 -> String.format("%.2f GB", b/(1024.0*1024*1024)); b>=1024*1024 -> String.format("%.2f MB", b/(1024.0*1024)); b>=1024 -> String.format("%.2f KB", b/1024.0); else -> "$b B" } }
    private fun updateStorageUsage(myId: Long) { val p=getPersonalDir(myId).walkTopDown().filter{it.isFile && it.name != MANIFEST_NAME}.sumOf{it.length()}; val s=getSharedDir(myId).walkTopDown().filter{it.isFile && it.name != MANIFEST_NAME}.sumOf{it.length()}; _storageUsage.value=p+s }
    fun clearCache(): Long { val c=File(context.cacheDir, "vault_cache").apply{mkdirs()}; val sz=c.walkTopDown().filter{it.isFile}.sumOf{it.length()}; c.deleteRecursively(); return sz }
    private fun getType(name: String): VaultType { val ext=name.substringAfterLast('.', "").lowercase(); return when(ext) { "jpg","jpeg","png","webp","gif"->VaultType.IMAGE; "mp4","mov","avi","mkv","webm"->VaultType.VIDEO; "pdf","doc","docx","xls","xlsx","txt","ppt","pptx"->VaultType.DOCUMENT; else->VaultType.OTHER } }
}
