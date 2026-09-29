package com.schatz.production

import android.content.Context
import com.schatz.production.managers.EnhancedVaultManager
import com.schatz.production.managers.SharedVaultCodec
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
 * Regression tests for the shared-vault disclosure fixes.
 *
 * The vault used to list every file under a single global vault_shared directory, with no
 * access filter and with manifest.txt included. That let the UI show the ownership manifest and
 * let a single delete destroy it, after which the vault re-adopted every remaining file as owned
 * by whoever was signed in.
 */
class VaultAccessControlTest {

    @get:Rule
    val temp = TemporaryFolder()

    private val myId = 77L
    private val otherId = 88L
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

    private fun sharedRoot(id: Long = myId) = File(context.filesDir, "vault_shared_$id").apply { mkdirs() }
    private fun writeShared(name: String, id: Long = myId) {
        val dir = sharedRoot(id)
        File(dir, name).writeText("x")
    }

    @Test
    fun `manifest is never listed as a shared file`() {
        writeShared("photo.jpg")
        File(sharedRoot(), "manifest.txt").writeText("id|name|1|2|3|4")

        manager.loadVaults(myId)

        assertFalse(
            "the ownership manifest must not be user-visible",
            manager.sharedFiles.value.any { it.name == "manifest.txt" }
        )
    }

    @Test
    fun `manifest is never listed as a personal file either`() {
        val personal = File(context.filesDir, "vault_personal_$myId").apply { mkdirs() }
        File(personal, "manifest.txt").writeText("junk")

        manager.loadVaults(myId)

        assertTrue(manager.personalFiles.value.none { it.name == "manifest.txt" })
    }

    @Test
    fun `manifest cannot be deleted through the vault ui`() {
        writeShared("photo.jpg")
        val manifest = File(sharedRoot(), "manifest.txt").apply { writeText("ownership data") }
        manager.loadVaults(myId)
        // Feed the manager the manifest's own name as if the listing filter had not removed it.
        val forgedId = manifest.name

        manager.deleteFile(forgedId, isShared = true, myId = myId)

        assertTrue("the ownership manifest must survive a delete", manifest.exists())
        assertTrue("an unrelated file must survive too", File(sharedRoot(), "photo.jpg").exists())
    }

    @Test
    fun `deleting a real shared file still works`() {
        writeShared("photo.jpg")
        manager.loadVaults(myId)
        val id = manager.sharedFiles.value.single().id

        manager.deleteFile(id, isShared = true, myId = myId)

        assertFalse(File(sharedRoot(), "photo.jpg").exists())
    }

    @Test
    fun `shared store is scoped per account`() {
        writeShared("mine.jpg", id = myId)
        writeShared("theirs.jpg", id = otherId)

        manager.loadVaults(myId)

        val names = manager.sharedFiles.value.map { it.name }
        assertTrue("mine.jpg" in names)
        assertFalse(
            "an account must not see another account's shared vault",
            "theirs.jpg" in names
        )
    }

    @Test
    fun `storage usage excludes the manifest and other accounts`() {
        File(sharedRoot(), "a.bin").writeBytes(ByteArray(100))
        File(sharedRoot(), "manifest.txt").writeText("x".repeat(5000))
        writeShared("b.bin", id = otherId)

        val formatted = manager.getStorageUsageFormatted(myId)

        // 100 bytes only: the 5000-byte manifest and the other account's file are both excluded.
        assertEquals("100 B", formatted)
    }

    @Test
    fun `delete cannot escape the account vault directory`() {
        writeShared("photo.jpg")
        manager.loadVaults(myId)
        val outside = File(context.filesDir, "outside.txt").apply { writeText("keep me") }
        val id = manager.sharedFiles.value.single().id

        manager.deleteFile(id, isShared = true, myId = myId)

        assertTrue("files outside the vault must be untouched", outside.exists())
    }

    @Test
    fun `canAccess still denies an unrelated user after the refactor`() {
        assertTrue(SharedVaultCodec.canAccess(ownerId = myId, sharedWithId = otherId, myId = otherId))
        assertFalse(SharedVaultCodec.canAccess(ownerId = myId, sharedWithId = otherId, myId = 999L))
    }
}
