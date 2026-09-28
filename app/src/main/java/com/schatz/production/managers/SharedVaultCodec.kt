package com.schatz.production.managers

import java.net.URLDecoder
import java.net.URLEncoder

// Shared Vault wire format + access rules.
// Pure Kotlin (no Android / TDLib imports) so the sharing contract can be
// verified standalone: encode/decode captions, persist/restore the manifest,
// and decide whether an entry is visible to the current user.
object SharedVaultCodec {
    const val MARKER = "[SHARED_VAULT]"
    const val VERSION = "v1"

    data class ShareMeta(val name: String, val sharedWithId: Long, val timestamp: Long)
    data class Entry(val id: String, val name: String, val ownerId: Long, val sharedWithId: Long, val timestamp: Long, val messageId: Long)

    private fun enc(value: String): String = URLEncoder.encode(value, "UTF-8")
    private fun dec(value: String): String = try { URLDecoder.decode(value, "UTF-8") } catch (e: Exception) { value }

    // Stable identity for a shared item: same owner + same file name => same entry.
    fun entryId(ownerId: Long, name: String): String = "${ownerId}_$name"

    // Strip any path components before a name touches the shared directory.
    fun sanitizeName(name: String): String {
        val cleaned = name.replace(Regex("[/\\\\]"), "_").trim()
        return when {
            cleaned.isEmpty() -> "file"
            cleaned == "." || cleaned == ".." -> "file"
            else -> cleaned
        }
    }

    // [SHARED_VAULT] v1|<name>|<sharedWithId>|<timestamp>
    fun buildCaption(name: String, sharedWithId: Long, timestamp: Long): String =
        "$MARKER $VERSION|${enc(name)}|$sharedWithId|$timestamp"

    // Returns null when the caption is not a shared vault item.
    // The sender id is never taken from the caption - the receiver reads it
    // from the TDLib message itself.
    fun parseCaption(caption: String): ShareMeta? {
        if (!caption.startsWith(MARKER)) return null
        val payload = caption.removePrefix(MARKER).trim()
        if (payload.isEmpty()) return null
        if (!payload.startsWith("$VERSION|")) {
            // Legacy "[SHARED_VAULT] <name>" format: recipient unknown, treat as
            // intended for the receiving user of this private chat.
            return ShareMeta(sanitizeName(payload), 0L, 0L)
        }
        val parts = payload.removePrefix("$VERSION|").split("|")
        if (parts.size != 3) return null
        val name = dec(parts[0])
        if (name.isEmpty()) return null
        val to = parts[1].toLongOrNull() ?: return null
        val ts = parts[2].toLongOrNull() ?: return null
        return ShareMeta(sanitizeName(name), to, ts)
    }

    // Access rule: an item is visible only when it was explicitly shared.
    //  - I am the recipient (someone shared it with me), or
    //  - I am the owner and I shared it with someone else.
    // Private vault content never enters this list at all (different directory,
    // never written to the manifest), so it cannot leak through this check.
    fun canAccess(ownerId: Long, sharedWithId: Long, myId: Long): Boolean {
        if (myId == 0L) return false
        if (ownerId == myId) return sharedWithId != 0L && sharedWithId != myId
        return ownerId != 0L && sharedWithId == myId
    }

    // Manifest persistence: one URL-encoded entry per line.
    fun encodeEntry(entry: Entry): String =
        listOf(enc(entry.id), enc(entry.name), entry.ownerId, entry.sharedWithId, entry.timestamp, entry.messageId).joinToString("|")

    fun decodeEntry(line: String): Entry? {
        val parts = line.trim().split("|")
        if (parts.size != 6) return null
        val name = dec(parts[1])
        if (name.isEmpty()) return null
        return Entry(
            id = dec(parts[0]),
            name = name,
            ownerId = parts[2].toLongOrNull() ?: return null,
            sharedWithId = parts[3].toLongOrNull() ?: return null,
            timestamp = parts[4].toLongOrNull() ?: return null,
            messageId = parts[5].toLongOrNull() ?: return null
        )
    }

    fun encodeManifest(entries: List<Entry>): String = entries.joinToString("\n") { encodeEntry(it) }

    fun decodeManifest(text: String): List<Entry> =
        text.lineSequence().mapNotNull { decodeEntry(it) }.toList()
}
