package com.schatz.production

import com.schatz.production.managers.SharedVaultCodec
import com.schatz.production.managers.SharedVaultCodec.Entry
import com.schatz.production.managers.SharedVaultCodec.ShareMeta
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SharedVaultCodec is deliberately pure Kotlin, so the whole sharing contract is verifiable
 * without a device or a TDLib client.
 */
class SharedVaultCodecTest {

    // ---- caption round trip ----

    @Test
    fun `caption round trips through parse`() {
        val caption = SharedVaultCodec.buildCaption("beach day.jpg", 4242L, 1_726_000_000_000L)
        val parsed = SharedVaultCodec.parseCaption(caption)

        assertNotNull(parsed)
        assertEquals("beach day.jpg", parsed!!.name)
        assertEquals(4242L, parsed.sharedWithId)
        assertEquals(1_726_000_000_000L, parsed.timestamp)
    }

    @Test
    fun `caption encodes characters that would break the pipe delimiter`() {
        // A raw "|" in the file name would otherwise be read as a field separator.
        val caption = SharedVaultCodec.buildCaption("a|b|c.png", 7L, 99L)
        val parsed = SharedVaultCodec.parseCaption(caption)

        assertNotNull(parsed)
        assertEquals("a|b|c.png", parsed!!.name)
        assertEquals(7L, parsed.sharedWithId)
        assertEquals(99L, parsed.timestamp)
    }

    @Test
    fun `parseCaption rejects an ordinary message`() {
        assertNull(SharedVaultCodec.parseCaption("Gising ka pa?"))
        assertNull(SharedVaultCodec.parseCaption(""))
    }

    @Test
    fun `parseCaption still accepts the legacy format with no version prefix`() {
        val parsed = SharedVaultCodec.parseCaption("${SharedVaultCodec.MARKER} old-file.pdf")
        assertNotNull(parsed)
        assertEquals("old-file.pdf", parsed!!.name)
        assertEquals(0L, parsed.sharedWithId)
    }

    @Test
    fun `parseCaption rejects a v1 payload with the wrong field count`() {
        assertNull(SharedVaultCodec.parseCaption("${SharedVaultCodec.MARKER} v1|onlyname"))
        assertNull(SharedVaultCodec.parseCaption("${SharedVaultCodec.MARKER} v1|a|b|c|d"))
    }

    // ---- name sanitising ----

    @Test
    fun `sanitizeName strips path separators so a name cannot escape its directory`() {
        assertEquals(".._.._etc_passwd", SharedVaultCodec.sanitizeName("../../etc/passwd"))
        assertEquals("_tmp_photo.jpg", SharedVaultCodec.sanitizeName("\\tmp\\photo.jpg"))
    }

    @Test
    fun `sanitizeName replaces empty and dot-only names`() {
        assertEquals("file", SharedVaultCodec.sanitizeName(""))
        assertEquals("file", SharedVaultCodec.sanitizeName("."))
        assertEquals("file", SharedVaultCodec.sanitizeName(".."))
    }

    @Test
    fun `a traversal payload cannot survive parse and rebuild a caption`() {
        val hostile = SharedVaultCodec.buildCaption("../../secret.txt", 1L, 1L)
        val parsed = SharedVaultCodec.parseCaption(hostile)
        assertNotNull(parsed)
        assertFalse(parsed!!.name.contains("/"))
    }

    // ---- access rules ----

    @Test
    fun `recipient can access an item shared with them`() {
        assertTrue(SharedVaultCodec.canAccess(ownerId = 10L, sharedWithId = 20L, myId = 20L))
    }

    @Test
    fun `owner can access an item they shared with somebody else`() {
        assertTrue(SharedVaultCodec.canAccess(ownerId = 10L, sharedWithId = 20L, myId = 10L))
    }

    @Test
    fun `an unrelated user cannot access a shared item`() {
        assertFalse(SharedVaultCodec.canAccess(ownerId = 10L, sharedWithId = 20L, myId = 30L))
    }

    @Test
    fun `nobody can access while myId is not yet known`() {
        // myId stays 0 until TDLib answers GetMe, so this guard prevents a window where an
        // unauthenticated viewer would see the shared list.
        assertFalse(SharedVaultCodec.canAccess(ownerId = 10L, sharedWithId = 20L, myId = 0L))
    }

    @Test
    fun `an item not shared with anyone is not visible even to its owner`() {
        assertFalse(SharedVaultCodec.canAccess(ownerId = 10L, sharedWithId = 0L, myId = 10L))
    }

    @Test
    fun `sharing an item with yourself does not grant access`() {
        assertFalse(SharedVaultCodec.canAccess(ownerId = 10L, sharedWithId = 10L, myId = 10L))
    }

    // ---- manifest persistence ----

    @Test
    fun `entry round trips`() {
        val entry = Entry(
            id = "10_beach day.jpg",
            name = "beach day.jpg",
            ownerId = 10L,
            sharedWithId = 20L,
            timestamp = 1_726_000_000_000L,
            messageId = 555L
        )
        val decoded = SharedVaultCodec.decodeEntry(SharedVaultCodec.encodeEntry(entry))

        assertNotNull(decoded)
        assertEquals(entry, decoded)
    }

    @Test
    fun `manifest round trips preserving order`() {
        val entries = listOf(
            Entry("10_a.png", "a.png", 10L, 20L, 3L, 31L),
            Entry("20_b.pdf", "b.pdf", 20L, 10L, 2L, 22L),
            Entry("10_c|weird.mp4", "c|weird.mp4", 10L, 20L, 1L, 11L)
        )
        val decoded = SharedVaultCodec.decodeManifest(SharedVaultCodec.encodeManifest(entries))

        assertEquals(entries, decoded)
    }

    @Test
    fun `a corrupt manifest line is skipped without losing the good ones`() {
        val text = listOf(
            SharedVaultCodec.encodeEntry(Entry("10_a.png", "a.png", 10L, 20L, 3L, 31L)),
            "this is not a manifest line",
            "",
            SharedVaultCodec.encodeEntry(Entry("10_b.png", "b.png", 10L, 20L, 2L, 22L))
        ).joinToString("\n")

        val decoded = SharedVaultCodec.decodeManifest(text)

        assertEquals(2, decoded.size)
        assertEquals("a.png", decoded[0].name)
        assertEquals("b.png", decoded[1].name)
    }

    @Test
    fun `decodeEntry rejects a non numeric field`() {
        assertNull(SharedVaultCodec.decodeEntry("id|name|notANumber|2|3|4"))
    }

    @Test
    fun `entryId is stable for the same owner and name`() {
        assertEquals(
            SharedVaultCodec.entryId(ownerId = 10L, name = "a.png"),
            SharedVaultCodec.entryId(ownerId = 10L, name = "a.png")
        )
    }

    @Test
    fun `entryId differs across owners`() {
        assertFalse(
            SharedVaultCodec.entryId(ownerId = 10L, name = "a.png") ==
                SharedVaultCodec.entryId(ownerId = 11L, name = "a.png")
        )
    }

    @Test
    fun `shareMeta exposes name recipient and timestamp`() {
        val meta = ShareMeta(name = "x.png", sharedWithId = 5L, timestamp = 7L)
        assertEquals("x.png", meta.name)
        assertEquals(5L, meta.sharedWithId)
        assertEquals(7L, meta.timestamp)
    }
}
