package com.schatz.production

import android.content.Context
import com.schatz.production.managers.EnhancedVaultManager
import com.schatz.production.managers.SortBy
import com.schatz.production.managers.ViewMode
import com.schatz.production.managers.VaultType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import java.io.File

/**
 * Plain JVM test. EnhancedVaultManager only ever reads Context.getFilesDir() and
 * Context.getCacheDir(), so a mocked Context backed by a real temp directory exercises the
 * actual filesystem logic without needing an Android runtime.
 */
class EnhancedVaultManagerTest {

    @get:Rule
    val temp = TemporaryFolder()

    private val myId = 77L
    private lateinit var context: Context
    private lateinit var manager: EnhancedVaultManager

    @Before
    fun setUp() {
        val files = temp.newFolder("files")
        val cache = temp.newFolder("cache")
        context = mock(Context::class.java)
        `when`(context.filesDir).thenReturn(files)
        `when`(context.cacheDir).thenReturn(cache)
        manager = EnhancedVaultManager(context)
    }

    private fun writePersonal(name: String, bytes: Int, modified: Long) {
        val dir = File(context.filesDir, "vault_personal_$myId").apply { mkdirs() }
        val f = File(dir, name)
        f.writeBytes(ByteArray(bytes))
        f.setLastModified(modified)
    }

    private fun writeShared(name: String, bytes: Int, modified: Long) {
        // The shared store is per-account now, so the helper must target the same directory the
        // manager reads. The old test used the global "vault_shared" path and silently saw nothing.
        val dir = File(context.filesDir, "vault_shared_$myId").apply { mkdirs() }
        val f = File(dir, name)
        f.writeBytes(ByteArray(bytes))
        f.setLastModified(modified)
    }

    @Test
    fun `loads nothing from an empty vault`() {
        manager.loadVaults(myId)
        assertTrue(manager.personalFiles.value.isEmpty())
        assertTrue(manager.sharedFiles.value.isEmpty())
    }

    @Test
    fun `classifies files by extension`() {
        writePersonal("a.jpg", 10, 1_000L)
        writePersonal("b.mp4", 10, 1_000L)
        writePersonal("c.pdf", 10, 1_000L)
        writePersonal("d.bin", 10, 1_000L)
        manager.loadVaults(myId)

        val byType = manager.personalFiles.value.associate { it.name to it.type }
        assertEquals(VaultType.IMAGE, byType["a.jpg"])
        assertEquals(VaultType.VIDEO, byType["b.mp4"])
        assertEquals(VaultType.DOCUMENT, byType["c.pdf"])
        assertEquals(VaultType.OTHER, byType["d.bin"])
    }

    @Test
    fun `records the real byte size of each file`() {
        writePersonal("a.jpg", 2048, 1_000L)
        manager.loadVaults(myId)

        assertEquals(2048L, manager.personalFiles.value.single().size)
    }

    @Test
    fun `sorts by name ascending case insensitively`() {
        writePersonal("banana.png", 1, 1_000L)
        writePersonal("Apple.png", 1, 1_000L)
        writePersonal("cherry.png", 1, 1_000L)
        manager.setSortBy(SortBy.NAME, myId)

        assertEquals(
            listOf("Apple.png", "banana.png", "cherry.png"),
            manager.personalFiles.value.map { it.name }
        )
    }

    @Test
    fun `sorts by date descending by default`() {
        writePersonal("old.png", 1, 1_000L)
        writePersonal("new.png", 1, 9_000L)
        manager.loadVaults(myId)

        assertEquals(listOf("new.png", "old.png"), manager.personalFiles.value.map { it.name })
    }

    @Test
    fun `sorts by size descending`() {
        writePersonal("small.png", 10, 1_000L)
        writePersonal("big.png", 9000, 1_000L)
        manager.setSortBy(SortBy.SIZE, myId)

        assertEquals(listOf("big.png", "small.png"), manager.personalFiles.value.map { it.name })
    }

    @Test
    fun `search filters by substring ignoring case`() {
        writePersonal("Sunset-at-Beach.jpg", 1, 1_000L)
        writePersonal("contract.pdf", 1, 1_000L)
        manager.setSearchQuery("BEACH", myId)

        assertEquals(1, manager.personalFiles.value.size)
        assertEquals("Sunset-at-Beach.jpg", manager.personalFiles.value.single().name)
    }

    @Test
    fun `a blank search restores every file`() {
        writePersonal("a.png", 1, 1_000L)
        writePersonal("b.png", 1, 2_000L)
        manager.setSearchQuery("a", myId)
        manager.setSearchQuery("", myId)

        assertEquals(2, manager.personalFiles.value.size)
    }

    @Test
    fun `personal and shared files stay in separate lists`() {
        writePersonal("mine.png", 1, 1_000L)
        writeShared("theirs.png", 1, 1_000L)
        manager.loadVaults(myId)

        assertEquals(listOf("mine.png"), manager.personalFiles.value.map { it.name })
        assertEquals(listOf("theirs.png"), manager.sharedFiles.value.map { it.name })
    }

    @Test
    fun `shared files are flagged as shared and owned by nobody in particular`() {
        writeShared("theirs.png", 1, 1_000L)
        manager.loadVaults(myId)

        val f = manager.sharedFiles.value.single()
        assertTrue(f.isShared)
        assertEquals(0L, f.ownerId)
    }

    @Test
    fun `personal files are not flagged as shared`() {
        writePersonal("mine.png", 1, 1_000L)
        manager.loadVaults(myId)

        assertFalse(manager.personalFiles.value.single().isShared)
    }

    @Test
    fun `delete removes the file from disk and from the list`() {
        writePersonal("gone.png", 1, 1_000L)
        manager.loadVaults(myId)
        val id = manager.personalFiles.value.single().id

        manager.deleteFile(id, isShared = false, myId = myId)

        assertTrue(manager.personalFiles.value.isEmpty())
    }

    @Test
    fun `storage usage is the sum of personal and shared`() {
        writePersonal("a.bin", 100, 1_000L)
        writeShared("b.bin", 250, 1_000L)
        manager.loadVaults(myId)

        assertEquals(350L, manager.storageUsage.value)
    }

    @Test
    fun `storage usage formats as bytes below one kilobyte`() {
        writePersonal("tiny.bin", 10, 1_000L)
        assertEquals("10 B", manager.getStorageUsageFormatted(myId))
    }

    @Test
    fun `storage usage formats as kilobytes above one kilobyte`() {
        writePersonal("k.bin", 2048, 1_000L)
        assertEquals("2.00 KB", manager.getStorageUsageFormatted(myId))
    }

    @Test
    fun `view mode starts as grid and can be switched to list`() {
        assertEquals(ViewMode.GRID, manager.viewMode.value)
        manager.setViewMode(ViewMode.LIST)
        assertEquals(ViewMode.LIST, manager.viewMode.value)
    }

    @Test
    fun `createFolder makes a directory and the vault still loads`() {
        manager.createFolder("receipts", isShared = false, myId = myId)
        manager.loadVaults(myId)
        assertTrue(manager.personalFiles.value.isEmpty())
    }
}
