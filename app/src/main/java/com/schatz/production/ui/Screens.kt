package com.schatz.production.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import com.schatz.production.BuildConfig
import com.schatz.production.R
import com.schatz.production.managers.*
import com.schatz.production.models.*
import org.drinkless.tdlib.TdApi
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun rememberVaultDownloader(): (String) -> Unit {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var pendingPath by remember { mutableStateOf<String?>(null) }

    fun runDownload(path: String) {
        val src = File(path)
        scope.launch {
            val ok = withContext(Dispatchers.IO) { src.exists() && saveToDownloads(context, src) }
            Toast.makeText(context, if(ok) "Saved to Downloads" else "Download failed", Toast.LENGTH_SHORT).show()
        }
    }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val path = pendingPath
        pendingPath = null
        if(granted && path != null) runDownload(path)
        else Toast.makeText(context, "Storage permission required", Toast.LENGTH_SHORT).show()
    }

    return { path ->
        if(Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            pendingPath = path
            launcher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        } else {
            runDownload(path)
        }
    }
}

/** Emoji offered on long-press. A couple chat does not need the full reaction catalogue. */
private val BUBBLE_REACTIONS = listOf("❤️", "👍", "😂", "😮", "😢", "🔥")

private fun isMediaPlaceholder(text: String): Boolean =
    text.startsWith("📷 ") || text.startsWith("🎥 ") || text.startsWith("🎤 ") || text.startsWith("🎵 ")

/**
 * One chat bubble: media rendering (photo/video/voice/document), reply quote, reaction chips,
 * the long-press menu (Reply / Copy / Delete - deliberately NO Forward, this is a 2-user app),
 * a tappable failed-tick for retry, and time/status.
 */
@Composable
private fun MessageBubble(
    msg: ChatMessage,
    chatManager: ChatManager,
    tdLib: TdLibUpdateManager,
    chatId: Long,
    mediaPaths: Map<Int, String>,
    downloadProgress: Int?,
    isPlaying: Boolean,
    onPlayToggle: (String) -> Unit,
    onOpenViewer: (String, Boolean) -> Unit,
    onSetReply: (Long) -> Unit,
    onRetry: (Long) -> Unit
) {
    var menuOpen by remember { mutableStateOf(false) }
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val bubbleColor = if (msg.fromMe) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
    val contentColor = if (msg.fromMe) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
    val path = mediaPaths[msg.mediaFileId]
    val showCaption = msg.mediaType != MediaType.TEXT && msg.text.isNotBlank() && !isMediaPlaceholder(msg.text)

    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (msg.fromMe) Arrangement.End else Arrangement.Start) {
        Box {
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = bubbleColor,
                modifier = Modifier.combinedClickable(
                    onClick = {},
                    onLongClick = { menuOpen = true }
                )
            ) {
                Column(Modifier.padding(12.dp, 8.dp)) {
                    // Quoted reply, rendered from the TextQuote TDLib carried on the message.
                    msg.replyToPreview?.let { quote ->
                        Surface(
                            color = contentColor.copy(alpha = 0.12f),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                "↩ $quote",
                                modifier = Modifier.padding(8.dp, 4.dp),
                                style = MaterialTheme.typography.labelSmall,
                                color = contentColor.copy(alpha = 0.8f),
                                maxLines = 2
                            )
                        }
                        Spacer(Modifier.height(4.dp))
                    }

                    when (msg.mediaType) {
                        MediaType.IMAGE -> {
                            if (path != null) {
                                AsyncImage(
                                    model = File(path),
                                    contentDescription = "Photo",
                                    modifier = Modifier
                                        .width(220.dp)
                                        .height(180.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .clickable { onOpenViewer(path, false) },
                                    contentScale = androidx.compose.ui.layout.ContentScale.Crop
                                )
                            } else {
                                Box(
                                    Modifier.width(220.dp).height(160.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(contentColor.copy(alpha = 0.08f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (downloadProgress != null) {
                                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                            CircularProgressIndicator(progress = downloadProgress / 100f, modifier = Modifier.size(36.dp))
                                            Spacer(Modifier.height(6.dp))
                                            Text("$downloadProgress%", style = MaterialTheme.typography.labelSmall, color = contentColor)
                                        }
                                    } else {
                                        Text("📷 Photo", color = contentColor)
                                    }
                                }
                            }
                        }

                        MediaType.VIDEO -> {
                            Box(
                                Modifier.width(220.dp).height(160.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(contentColor.copy(alpha = 0.08f))
                                    .clickable {
                                        if (path != null) onOpenViewer(path, true)
                                        else chatManager.downloadMedia(msg)
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                if (downloadProgress != null) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        CircularProgressIndicator(progress = downloadProgress / 100f, modifier = Modifier.size(36.dp))
                                        Spacer(Modifier.height(6.dp))
                                        Text("$downloadProgress%", style = MaterialTheme.typography.labelSmall, color = contentColor)
                                    }
                                } else {
                                    Text(if (path != null) "▶ 🎥 Video" else "🎥 Video", color = contentColor)
                                }
                            }
                        }

                        MediaType.VOICE, MediaType.AUDIO -> {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                if (path != null) {
                                    IconButton(onClick = { onPlayToggle(path) }) {
                                        Text(if (isPlaying) "⏸" else "▶", style = MaterialTheme.typography.titleMedium, color = contentColor)
                                    }
                                    Text(msg.text, style = MaterialTheme.typography.bodyMedium, color = contentColor)
                                } else if (downloadProgress != null) {
                                    CircularProgressIndicator(progress = downloadProgress / 100f, modifier = Modifier.size(24.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("$downloadProgress%", style = MaterialTheme.typography.labelSmall, color = contentColor)
                                } else {
                                    Text(msg.text, style = MaterialTheme.typography.bodyMedium, color = contentColor)
                                }
                            }
                        }

                        MediaType.DOCUMENT -> {
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable {
                                if (path == null) chatManager.downloadMedia(msg)
                                else scope.launch(Dispatchers.IO) {
                                    val ok = saveToDownloads(context, File(path))
                                    kotlinx.coroutines.withContext(Dispatchers.Main) {
                                        Toast.makeText(context, if (ok) "Saved to Downloads" else "Save failed", Toast.LENGTH_SHORT).show()
                                    }
                                }
                            }) {
                                if (downloadProgress != null) {
                                    CircularProgressIndicator(progress = downloadProgress / 100f, modifier = Modifier.size(20.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("$downloadProgress%", style = MaterialTheme.typography.labelSmall, color = contentColor)
                                } else {
                                    Text(msg.text, style = MaterialTheme.typography.bodyMedium, color = contentColor)
                                    if (path != null) { Spacer(Modifier.width(6.dp)); Text("⤓", color = contentColor) }
                                }
                            }
                        }

                        else -> {
                            Text(msg.text, style = MaterialTheme.typography.bodyMedium, color = contentColor)
                        }
                    }

                    if (showCaption) {
                        Spacer(Modifier.height(4.dp))
                        Text(msg.text, style = MaterialTheme.typography.bodyMedium, color = contentColor)
                    }

                    // Reaction chips: tap to take your own reaction, tap again to remove it.
                    if (msg.reactions.isNotEmpty()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(top = 4.dp)) {
                            msg.reactions.forEach { reaction ->
                                Surface(
                                    shape = RoundedCornerShape(12.dp),
                                    color = if (reaction.isMine) MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)
                                    else contentColor.copy(alpha = 0.10f),
                                    modifier = Modifier.clickable {
                                        if (reaction.isMine) tdLib.removeReaction(chatId, msg.id, reaction.emoji)
                                        else tdLib.addReaction(chatId, msg.id, reaction.emoji)
                                    }
                                ) {
                                    Text(
                                        "${reaction.emoji} ${reaction.count}",
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = contentColor
                                    )
                                }
                            }
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = java.text.SimpleDateFormat("HH:mm").format(java.util.Date(msg.timestamp)),
                            style = MaterialTheme.typography.labelSmall,
                            color = contentColor.copy(alpha = 0.6f)
                        )
                        if (msg.fromMe) {
                            Spacer(Modifier.width(4.dp))
                            val statusText = when (msg.status) {
                                MessageStatus.SENDING -> "○"
                                MessageStatus.SENT -> "✓"
                                MessageStatus.DELIVERED -> "✓✓"
                                MessageStatus.READ -> "✓✓"
                                MessageStatus.FAILED -> "!"
                            }
                            if (msg.status == MessageStatus.FAILED) {
                                Text(
                                    text = statusText,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error,
                                    modifier = Modifier
                                        .clickable { onRetry(msg.id) }
                                        .padding(start = 4.dp)
                                )
                            } else {
                                Text(text = statusText, style = MaterialTheme.typography.labelSmall, color = contentColor.copy(alpha = 0.7f))
                            }
                        }
                    }
                }
            }

            // Long-press menu. Reply / Copy / Delete only - Forward is intentionally absent.
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.padding(horizontal = 8.dp)
                ) {
                    BUBBLE_REACTIONS.forEach { emoji ->
                        TextButton(onClick = {
                            val mine = msg.reactions.any { it.emoji == emoji && it.isMine }
                            if (mine) tdLib.removeReaction(chatId, msg.id, emoji)
                            else tdLib.addReaction(chatId, msg.id, emoji)
                            menuOpen = false
                        }) { Text(emoji) }
                    }
                }
                Divider()
                DropdownMenuItem(
                    text = { Text("Reply") },
                    leadingIcon = { Text("↩") },
                    onClick = { onSetReply(msg.id); menuOpen = false }
                )
                DropdownMenuItem(
                    text = { Text("Copy") },
                    leadingIcon = { Text("⧉") },
                    onClick = {
                        clipboard.setText(AnnotatedString(msg.text))
                        menuOpen = false
                    }
                )
                DropdownMenuItem(
                    text = { Text("Delete") },
                    leadingIcon = { Text("🗑") },
                    onClick = {
                        chatManager.deleteMessage(msg.id, forBoth = msg.fromMe)
                        menuOpen = false
                    }
                )
            }
        }
    }
}

@Composable
fun ChatScreen(tdLib: TdLibUpdateManager, connectionManager: ConnectionManager, voiceManager: VoiceMessageManager) {
    val context = LocalContext.current
    val connectionState by connectionManager.state.collectAsState()
    val privateChat by connectionManager.privateChat.collectAsState()
    var chatManager by remember { mutableStateOf<ChatManager?>(null) }

    // Initialize ChatManager with full history/pagination when chat ready
    val resolvedMyId by connectionManager.myId.collectAsState()
    LaunchedEffect(privateChat, resolvedMyId) {
        if(privateChat != null && resolvedMyId != 0L) {
            val manager = ChatManager(tdLib)
            manager.init(resolvedMyId, privateChat!!.id)
            chatManager = manager

        }
    }

    val messages = chatManager?.messages?.collectAsState()?.value ?: emptyList()
    val isLoadingHistory = chatManager?.isLoadingHistory?.collectAsState()?.value ?: false
    val hasMoreHistory = chatManager?.hasMoreHistory?.collectAsState()?.value ?: true
    val dateSeparators = chatManager?.dateSeparators?.collectAsState()?.value ?: emptyMap()
    val mediaPaths = chatManager?.mediaPaths?.collectAsState()?.value ?: emptyMap()
    val mediaDownloads = chatManager?.mediaDownloads?.collectAsState()?.value ?: emptyMap()
    val partnerTyping = chatManager?.partnerTyping?.collectAsState()?.value ?: false

    var text by remember { mutableStateOf("") }
    var replyTo by remember { mutableStateOf<Long?>(null) }

    // Chat state: scroll target, server search, playback, and the full-screen media viewer.
    val listState = rememberLazyListState()
    var searchOpen by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<ChatMessage>>(emptyList()) }
    var playingPath by remember { mutableStateOf<String?>(null) }
    var viewerPath by remember { mutableStateOf<String?>(null) }
    var viewerIsVideo by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current

    // Throttle: TDLib wants at most one typing action every few seconds per chat.
    var lastTypingSent by remember { mutableStateOf(0L) }

    val recordingState by voiceManager.recordingState.collectAsState()
    val recordingDuration by voiceManager.recordingDuration.collectAsState()
    val amplitudes by voiceManager.amplitudes.collectAsState()
    val playbackState by voiceManager.playbackState.collectAsState()

    // Load older pages whenever the top of the history (the pagination row) comes into view.
    // The previous LaunchedEffect(Unit) fired exactly once, so history stopped after the first
    // page no matter how far the user scrolled.
    LaunchedEffect(listState, chatManager) {
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1 }
            .collect { lastVisible ->
                if (lastVisible >= 0 && hasMoreHistory && !isLoadingHistory && lastVisible >= messages.size - 1) {
                    chatManager?.loadMoreHistory()
                }
            }
    }

    Column(Modifier.fillMaxSize()) {
        if(connectionState != ConnectionState.CONNECTED) {
            Surface(color=MaterialTheme.colorScheme.surfaceVariant, modifier=Modifier.fillMaxWidth()) {
                Text(text=when(connectionState) {
                    ConnectionState.CONNECTING -> "Connecting..."
                    ConnectionState.RECONNECTING -> "Reconnecting... • Messages will send when online"
                    ConnectionState.OFFLINE -> "Offline • Check internet"
                    ConnectionState.ERROR -> "Connection error • Retrying..."
                    else -> ""
                }, modifier=Modifier.padding(8.dp), style=MaterialTheme.typography.labelSmall)
            }
        }

        // Search: a slim row that expands into the query field; results replace the transcript
        // until one is tapped (then the list jumps to that message).
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            if (searchOpen) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = {
                        searchQuery = it
                        chatManager?.searchRemote(it) { searchResults = it }
                    },
                    placeholder = { Text("Search messages...") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(20.dp)
                )
                TextButton(onClick = { searchOpen = false; searchQuery = ""; searchResults = emptyList() }) { Text("✕") }
            } else {
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { searchOpen = true }) { Text("🔍 Search") }
            }
        }

        // Chat with history/pagination, date separators, scroll-to-message
        Box(Modifier.weight(1f)) {
            if (searchOpen && searchQuery.isNotBlank()) {
                if (searchResults.isEmpty()) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("No matches", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                    }
                } else {
                    LazyColumn(Modifier.fillMaxSize().padding(8.dp)) {
                        items(searchResults) { hit ->
                            ListItem(
                                headlineContent = { Text(hit.text.take(80), maxLines = 2) },
                                supportingContent = {
                                    Text(java.text.SimpleDateFormat("MMM dd, HH:mm").format(java.util.Date(hit.timestamp)))
                                },
                                modifier = Modifier.clickable {
                                    chatManager?.jumpToMessage(hit.id) { index ->
                                        if (index >= 0) {
                                            searchOpen = false
                                            scope.launch { listState.animateScrollToItem(index) }
                                        }
                                    }
                                }
                            )
                            Divider()
                        }
                    }
                }
            } else {
            LazyColumn(state = listState, modifier=Modifier.fillMaxSize().padding(16.dp), verticalArrangement=Arrangement.spacedBy(8.dp), reverseLayout=true) {
                items(messages.reversed()) { msg ->
                    val cm = chatManager
                    // Date separator
                    dateSeparators[msg.id]?.let { date ->
                        Box(Modifier.fillMaxWidth().padding(vertical=8.dp), contentAlignment=Alignment.Center) {
                            Surface(shape=RoundedCornerShape(12.dp), color=MaterialTheme.colorScheme.surfaceVariant) {
                                Text(date, modifier=Modifier.padding(8.dp,4.dp), style=MaterialTheme.typography.labelSmall)
                            }
                        }
                    }

                    if (cm != null) {
                        MessageBubble(
                            msg = msg,
                            chatManager = cm,
                            tdLib = tdLib,
                            chatId = privateChat?.id ?: 0L,
                            mediaPaths = mediaPaths,
                            downloadProgress = mediaDownloads[msg.mediaFileId],
                            isPlaying = playingPath != null && playingPath == mediaPaths[msg.mediaFileId] && playbackState == PlaybackState.PLAYING,
                            onPlayToggle = { path ->
                                if (playingPath == path && playbackState == PlaybackState.PLAYING) {
                                    voiceManager.stopPlayback(); playingPath = null
                                } else {
                                    voiceManager.startPlayback(path); playingPath = path
                                }
                            },
                            onOpenViewer = { path, isVideo -> viewerPath = path; viewerIsVideo = isVideo },
                            onSetReply = { replyTo = it },
                            onRetry = { chatManager?.retryFailedMessage(it) }
                        )
                    }
                }

                // Spinner for an in-flight older page. The load trigger itself lives in the
                // snapshotFlow above, keyed to real scroll visibility.
                item {
                    if(isLoadingHistory) {
                        Box(Modifier.fillMaxWidth().padding(8.dp), contentAlignment=Alignment.Center) {
                            CircularProgressIndicator(modifier=Modifier.size(20.dp))
                        }
                    }
                }
            }
            }
        }

        // Voice recording UI
        if(recordingState == RecordingState.RECORDING) {
            Surface(color=MaterialTheme.colorScheme.errorContainer, modifier=Modifier.fillMaxWidth()) {
                Row(Modifier.padding(12.dp), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.SpaceBetween) {
                    Row(verticalAlignment=Alignment.CenterVertically) {
                        Box(Modifier.size(12.dp).clip(RoundedCornerShape(6.dp)).background(MaterialTheme.colorScheme.error))
                        Spacer(Modifier.width(8.dp))
                        Text("${recordingDuration/60}:${(recordingDuration%60).toString().padStart(2,'0')}", style=MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.width(12.dp))
                        Row(Modifier.width(100.dp).height(24.dp), horizontalArrangement=Arrangement.spacedBy(2.dp), verticalAlignment=Alignment.CenterVertically) {
                            amplitudes.takeLast(15).forEach { amp ->
                                Box(Modifier.width(3.dp).height((amp.coerceAtLeast(2)).dp).clip(RoundedCornerShape(2.dp)).background(MaterialTheme.colorScheme.error))
                            }
                        }
                    }
                    Row {
                        TextButton(onClick={ voiceManager.cancelRecording() }) { Text("Cancel") }
                        Button(onClick={
                            val file = voiceManager.stopRecording()
                            file?.let {
                                chatManager?.let { cm ->
                                    // Send via FileManager in real app
                                    tdLib.sendFile(privateChat!!.id, it.absolutePath)
                                }
                            }
                        }) { Text("Send") }
                    }
                }
            }
        }

        // Reply preview
        replyTo?.let { replyId ->
            val replyMsg = messages.find { it.id == replyId }
            replyMsg?.let {
                Surface(color=MaterialTheme.colorScheme.surfaceVariant, modifier=Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(12.dp), verticalAlignment=Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Replying to", style=MaterialTheme.typography.labelSmall, color=MaterialTheme.colorScheme.primary)
                            Text(it.text.take(50), style=MaterialTheme.typography.bodySmall, maxLines=1)
                        }
                        IconButton(onClick={ replyTo = null }) { Text("✕") }
                    }
                }
            }
        }

        // Partner typing indicator. Cleared by ChatActionCancel or the 6s timeout in ChatManager.
        if (partnerTyping) {
            Surface(color=MaterialTheme.colorScheme.surfaceVariant, modifier=Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
                Text(
                    "typing…",
                    modifier=Modifier.padding(12.dp, 6.dp),
                    style=MaterialTheme.typography.labelSmall,
                    color=MaterialTheme.colorScheme.primary
                )
            }
        }

        // Composer
        // The picker is declared here rather than inside the Row: the result callback captures the
        // coroutine scope, which must come from a composable scope rather than a click handler.
        val stager = remember(context) { AttachmentStager(context) }
        val sendScope = rememberCoroutineScope()
        val pickFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            val chatId = privateChat?.id
            if (uri == null || chatId == null) return@rememberLauncherForActivityResult
            sendScope.launch {
                val staged = withContext(Dispatchers.IO) { stager.stage(uri) }
                if (staged == null) {
                    Toast.makeText(context, "Could not read that file", Toast.LENGTH_SHORT).show()
                    return@launch
                }
                stager.send(staged, chatId, tdLib) { _, _ ->
                    sendScope.launch(Dispatchers.IO) { stager.clearStaged() }
                }
            }
        }
        Row(Modifier.padding(12.dp).fillMaxWidth(), verticalAlignment=Alignment.CenterVertically) {
            IconButton(onClick={ pickFile.launch(arrayOf("*/*")) }) { Text("+") }
            OutlinedTextField(
                value=text,
                onValueChange={ value ->
                    text = value
                    // Tell the partner we are typing (throttled to one action per 5s).
                    val now = System.currentTimeMillis()
                    if (value.isNotBlank() && now - lastTypingSent > 5000) {
                        lastTypingSent = now
                        privateChat?.let { tdLib.sendTyping(it.id) }
                    }
                },
                placeholder={Text("Message...")},
                trailingIcon={
                    IconButton(onClick={
                        if(recordingState == RecordingState.RECORDING) {
                            voiceManager.stopRecording()?.let { file ->
                                privateChat?.let { chat ->
                                    tdLib.sendFile(chat.id, file.absolutePath)
                                }
                            }
                        } else {
                            voiceManager.startRecording()
                        }
                    }) {
                        if(recordingState == RecordingState.RECORDING) {
                            Icon(painterResource(R.drawable.ic_stop_24), contentDescription="Stop recording")
                        } else {
                            Icon(painterResource(R.drawable.ic_mic_24), contentDescription="Voice message")
                        }
                    }
                },
                modifier=Modifier.weight(1f),
                shape=RoundedCornerShape(20.dp)
            )
            Spacer(Modifier.width(8.dp))
            Button(onClick={
                if(text.isNotBlank()) {
                    chatManager?.sendMessage(text, replyTo ?: 0)
                    text = ""
                    replyTo = null
                }
            }, shape=RoundedCornerShape(12.dp), enabled=text.isNotBlank() && connectionState==ConnectionState.CONNECTED) { Text("↑") }
        }

        // Full-screen photo / video viewer, opened from a media bubble.
        viewerPath?.let { path ->
            MediaViewer(path = path, isVideo = viewerIsVideo, onDismiss = { viewerPath = null })
        }
    }
}

@Composable
fun CallHistoryScreen(callHistoryManager: CallHistoryManager, callManager: CallManager, partnerId: Long) {
    val history by callHistoryManager.history.collectAsState()
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement=Arrangement.SpaceBetween, verticalAlignment=Alignment.CenterVertically) {
            Text("Call History", style=MaterialTheme.typography.titleMedium)
            TextButton(onClick={ callHistoryManager.clearHistory() }) { Text("Clear") }
        }
        if(history.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment=Alignment.Center) {
                Column(horizontalAlignment=Alignment.CenterHorizontally) {
                    Text("No calls yet", style=MaterialTheme.typography.bodyMedium)
                    Text("Your call history will appear here", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                }
            }
        } else {
            LazyColumn(Modifier.fillMaxSize()) {
                items(history) { item ->
                    ListItem(
                        headlineContent={ Text("${if(item.type == CallType.INCOMING) "Incoming" else if(item.type == CallType.OUTGOING) "Outgoing" else item.type.name} • ${if(item.media == CallMedia.VIDEO) "Video" else "Audio"}") },
                        supportingContent={ Text("${java.text.SimpleDateFormat("MMM dd, HH:mm").format(java.util.Date(item.timestamp))} • ${if(item.duration > 0) "${item.duration/60}:${(item.duration%60).toString().padStart(2,'0')}" else item.type.name}") },
                        leadingContent={
                            Surface(shape=RoundedCornerShape(20.dp), color=when(item.type) {
                                CallType.MISSED, CallType.FAILED -> MaterialTheme.colorScheme.errorContainer
                                else -> MaterialTheme.colorScheme.surfaceVariant
                            }, modifier=Modifier.size(40.dp)) {
                                Box(contentAlignment=Alignment.Center) {
                                    Text(when(item.type) {
                                        CallType.INCOMING -> "↙️"
                                        CallType.OUTGOING -> "↗️"
                                        CallType.MISSED -> "↙️"
                                        else -> "📞"
                                    })
                                }
                            }
                        },
                        trailingContent={ IconButton(onClick={ callManager.startCall(item.partnerId, item.media == CallMedia.VIDEO) }) { Text("📞") } }
                    )
                    Divider()
                }
            }
        }
    }
}

@Composable
fun VaultScreen(vaultManager: VaultManager, myId: Long) {
    var tab by remember { mutableStateOf(0) }
    val personalFiles by vaultManager.personalFiles.collectAsState()
    val sharedFiles by vaultManager.sharedFiles.collectAsState()
    LaunchedEffect(myId) { if(myId != 0L) vaultManager.loadVaults(myId) }

    // For shared vault with real sync, use SharedVaultSyncManager in real app
    Column {
        Row(Modifier.padding(12.dp), horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            FilterChip(selected=tab==0, onClick={tab=0}, label={Text("Personal")})
            FilterChip(selected=tab==1, onClick={tab=1}, label={Text("Shared")})
        }
        val files = if(tab==0) personalFiles else sharedFiles
        LazyColumn(Modifier.fillMaxSize().padding(12.dp), verticalArrangement=Arrangement.spacedBy(16.dp)) {
            item {
                Text("Pictures", style=MaterialTheme.typography.labelMedium)
                Spacer(Modifier.height(8.dp))
                val images = files.filter { it.type == VaultManager.VaultType.IMAGE }
                if(images.isEmpty()) Text("No pictures yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                else LazyVerticalGrid(columns=GridCells.Fixed(3), modifier=Modifier.height(200.dp), horizontalArrangement=Arrangement.spacedBy(6.dp), verticalArrangement=Arrangement.spacedBy(6.dp)) {
                    items(images) { file ->
                        Box(Modifier.aspectRatio(1f).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment=Alignment.Center) { Text(file.name.take(10), style=MaterialTheme.typography.labelSmall) }
                    }
                }
            }
            item {
                Text("Videos", style=MaterialTheme.typography.labelMedium)
                Spacer(Modifier.height(8.dp))
                val videos = files.filter { it.type == VaultManager.VaultType.VIDEO }
                if(videos.isEmpty()) Text("No videos yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                else LazyVerticalGrid(columns=GridCells.Fixed(2), modifier=Modifier.height(160.dp), horizontalArrangement=Arrangement.spacedBy(8.dp), verticalArrangement=Arrangement.spacedBy(8.dp)) {
                    items(videos) { file ->
                        Box(Modifier.fillMaxWidth().height(80.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment=Alignment.Center) { Text("${file.name} • ${file.size/1024/1024} MB", style=MaterialTheme.typography.labelSmall) }
                    }
                }
            }
            item { Text("Files", style=MaterialTheme.typography.labelMedium); Spacer(Modifier.height(8.dp)) }
            val docs = files.filter { it.type == VaultManager.VaultType.DOCUMENT || it.type == VaultManager.VaultType.OTHER }
            if(docs.isEmpty()) {
                item { Text("No files yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f)) }
            } else {
                items(docs.size) { idx ->
                    val file = docs[idx]
                    ListItem(headlineContent={Text(file.name)}, supportingContent={Text("${file.size/1024} KB")}, leadingContent={ Surface(shape=RoundedCornerShape(8.dp), color=MaterialTheme.colorScheme.primary, modifier=Modifier.size(36.dp)) { Box(contentAlignment=Alignment.Center) { Text(file.name.substringAfterLast('.', "").take(3).uppercase(), color=MaterialTheme.colorScheme.onPrimary, style=MaterialTheme.typography.labelSmall) } } })
                    Divider()
                }
            }
        }
    }
}

@Composable
fun VaultScreenWithSync(syncManager: SharedVaultSyncManager, myId: Long, partnerName: String = "Her", onBackToChat:()->Unit) {
    var selecting by remember { mutableStateOf(false) }
    val picked = remember { mutableStateOf(setOf<String>()) }
    val files by syncManager.files.collectAsState()
    val syncState by syncManager.syncState.collectAsState()
    val download = rememberVaultDownloader()

    fun ownerLabel(ownerId: Long) = if(ownerId == myId) "You" else partnerName

    Column {
        Row(Modifier.fillMaxWidth(), verticalAlignment=Alignment.CenterVertically) {
            IconButton(onClick={ selecting=false; onBackToChat() }) { Icon(painterResource(R.drawable.ic_arrow_back_24), contentDescription="Back to Chat") }
            Text("Vault", style=MaterialTheme.typography.titleMedium, modifier=Modifier.padding(start=4.dp))
        }
        Row(Modifier.padding(horizontal=12.dp).fillMaxWidth(), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.SpaceBetween) {
            TextButton(onClick={ selecting=!selecting; if(!selecting) picked.value=setOf() }) { Text(if(selecting) "Done" else "Select") }
            Row(verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                if(syncState == SyncState.SYNCING) CircularProgressIndicator(modifier=Modifier.size(16.dp))
                Text(text=when(syncState) {
                    SyncState.SYNCED -> "Synced"
                    SyncState.SYNCING -> "Syncing..."
                    SyncState.FAILED -> "Sync failed"
                    SyncState.OFFLINE -> "Offline"
                }, style=MaterialTheme.typography.labelSmall)
            }
        }

        if(selecting && picked.value.isNotEmpty()) {
            val pickedCount = picked.value.size
            Row(Modifier.fillMaxWidth().padding(horizontal=12.dp), horizontalArrangement=Arrangement.End) {
                FilledTonalButton(onClick={
                    picked.value.forEach { syncManager.deleteFromShared(it) }
                    picked.value = setOf()
                    selecting = false
                }) { Text("Delete $pickedCount") }
            }
        }

        val media = files.filter { it.type == VaultManager.VaultType.IMAGE }
        val videos = files.filter { it.type == VaultManager.VaultType.VIDEO }
        val docs = files.filter { it.type == VaultManager.VaultType.DOCUMENT || it.type == VaultManager.VaultType.OTHER }

        LazyColumn(Modifier.fillMaxSize().padding(12.dp), verticalArrangement=Arrangement.spacedBy(16.dp)) {
            item {
                Text("Media", style=MaterialTheme.typography.labelMedium)
                Spacer(Modifier.height(8.dp))
                if(media.isEmpty()) Text("No media yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                else LazyVerticalGrid(columns=GridCells.Fixed(3), modifier=Modifier.height(200.dp), horizontalArrangement=Arrangement.spacedBy(6.dp), verticalArrangement=Arrangement.spacedBy(6.dp)) {
                    items(media) { file ->
                        Box(Modifier.aspectRatio(1f).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant).clickable { if(selecting) { picked.value = if(picked.value.contains(file.id)) picked.value - file.id else picked.value + file.id } else { download(file.path) } }, contentAlignment=Alignment.Center) {
                            Column(horizontalAlignment=Alignment.CenterHorizontally) {
                                Text(file.name.take(8), style=MaterialTheme.typography.labelSmall)
                                Text("${ownerLabel(file.ownerId)} • ${when(file.syncState) {
                                    SyncState.SYNCED -> "✓"
                                    SyncState.SYNCING -> "↻"
                                    else -> "!"
                                }}", style=MaterialTheme.typography.labelSmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                            }
                            if(selecting) Box(Modifier.align(Alignment.TopEnd).padding(6.dp).size(18.dp).clip(CircleShape).background(if(picked.value.contains(file.id)) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha=0.35f)))
                        }
                    }
                }
            }
            item {
                Text("Videos", style=MaterialTheme.typography.labelMedium)
                Spacer(Modifier.height(8.dp))
                if(videos.isEmpty()) Text("No videos yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                else LazyVerticalGrid(columns=GridCells.Fixed(2), modifier=Modifier.height(160.dp), horizontalArrangement=Arrangement.spacedBy(8.dp), verticalArrangement=Arrangement.spacedBy(8.dp)) {
                    items(videos) { file ->
                        Box(Modifier.fillMaxWidth().height(80.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant).clickable { if(selecting) { picked.value = if(picked.value.contains(file.id)) picked.value - file.id else picked.value + file.id } else { download(file.path) } }, contentAlignment=Alignment.Center) {
                            Column(horizontalAlignment=Alignment.CenterHorizontally) {
                                Text(file.name, style=MaterialTheme.typography.labelSmall)
                                Text(ownerLabel(file.ownerId), style=MaterialTheme.typography.labelSmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f))
                            }
                            if(selecting) Box(Modifier.align(Alignment.TopEnd).padding(6.dp).size(18.dp).clip(CircleShape).background(if(picked.value.contains(file.id)) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha=0.35f)))
                        }
                    }
                }
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.SpaceBetween, verticalAlignment=Alignment.CenterVertically) {
                    Text("Files", style=MaterialTheme.typography.labelMedium)
                    TextButton(onClick={ syncManager.syncNow() }) { Text("Sync now") }
                }
                Spacer(Modifier.height(8.dp))
            }
            if(docs.isEmpty()) {
                item { Text("No files yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f)) }
            } else {
                items(docs.size) { idx ->
                    val file = docs[idx]
                    ListItem(
                        headlineContent={Text(file.name)},
                        supportingContent={Text("${file.size/1024} KB • ${file.syncState.name} • ${ownerLabel(file.ownerId)}")},
                        leadingContent={ Surface(shape=RoundedCornerShape(8.dp), color=MaterialTheme.colorScheme.primary, modifier=Modifier.size(36.dp)) { Box(contentAlignment=Alignment.Center) { Text(file.name.substringAfterLast('.', "").take(3).uppercase(), color=MaterialTheme.colorScheme.onPrimary, style=MaterialTheme.typography.labelSmall) } } },
                        trailingContent={
                            Row {
                                IconButton(onClick={ download(file.path) }) { Icon(painterResource(R.drawable.ic_download_24), contentDescription="Download") }
                                IconButton(onClick={ syncManager.deleteFromShared(file.id) }) { Text("🗑️") }
                            }
                        }
                    )
                    Divider()
                }
            }
        }
    }
}

@Composable
fun SettingsScreen(
    securityManager: SecurityManager,
    enhancedVaultManager: EnhancedVaultManager,
    me: TdApi.User?,
    isDark: Boolean,
    onToggleDark: ()->Unit,
    onBackToChat: ()->Unit,
    onOpenCallHistory: ()->Unit,
    onOpenVault: ()->Unit,
    onLogout: ()->Unit,
    onSetPin: ()->Unit
) {
    val context = LocalContext.current
    var biometricOn by remember { mutableStateOf(securityManager.isBiometricEnabled()) }
    var storage by remember { mutableStateOf(enhancedVaultManager.getStorageUsageFormatted(0L)) }
    var cacheBytes by remember { mutableStateOf(-1L) }
    val biometricAvailable = remember { securityManager.isBiometricAvailable() }
    val pinSet = remember { securityManager.isPinSet() }

    fun refreshStorage() { storage = enhancedVaultManager.getStorageUsageFormatted(0L) }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(start=4.dp)) {
            IconButton(onClick={ onBackToChat() }) { Icon(painterResource(R.drawable.ic_arrow_back_24), contentDescription="Back to Chat") }
        }
        LazyColumn(Modifier.weight(1f).padding(16.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
        item {
            Text("General", style=MaterialTheme.typography.labelSmall)
            Card(shape=RoundedCornerShape(16.dp)) {
                Column {
                    ListItem(headlineContent={Text("Call History")}, supportingContent={Text("Recent calls")}, trailingContent={Text("›")}, modifier=Modifier.clickable { onOpenCallHistory() })
                    Divider()
                    ListItem(headlineContent={Text("Vault")}, supportingContent={Text("Shared media, videos and files")}, trailingContent={Text("›")}, modifier=Modifier.clickable { onOpenVault() })
                }
            }
        }
        item {
            Text("Account", style=MaterialTheme.typography.labelSmall)
            Card(shape=RoundedCornerShape(16.dp)) {
                Column {
                    // These were the hardcoded strings "+63 9XX XXX XXXX", "@schatz_user" and
                    // "Private for us two"; they now read the signed-in Telegram profile.
                    ListItem(
                        headlineContent={Text("Phone Number")},
                        supportingContent={ Text(
                            when {
                                me == null -> "Loading..."
                                me.phoneNumber.isNotBlank() -> me.phoneNumber
                                else -> "Hidden in Telegram"
                            }
                        )}
                    )
                    Divider()
                    ListItem(
                        headlineContent={Text("Username")},
                        supportingContent={ Text(
                            me?.usernames?.activeUsernames?.firstOrNull()?.let { "@$it" } ?: "None set"
                        )}
                    )
                    Divider()
                    ListItem(
                        headlineContent={Text("Display name")},
                        supportingContent={ Text(if (me?.firstName.isNullOrBlank()) "None set" else me?.firstName.orEmpty()) }
                    )
                    Divider()
                    ListItem(
                        headlineContent={Text("Logout")},
                        supportingContent={Text("Clear session and local data")},
                        trailingContent={Text("›")},
                        modifier=Modifier.clickable { onLogout() }
                    )
                }
            }
        }
        item {
            Text("Data and Storage", style=MaterialTheme.typography.labelSmall)
            Card(shape=RoundedCornerShape(16.dp)) {
                Column {
                    // Was a literal "4.8 GB used" while a real formatter already existed.
                    ListItem(headlineContent={Text("Storage Usage")}, supportingContent={Text(storage)})
                    Divider()
                    ListItem(
                        headlineContent={Text("Clear Cache")},
                        supportingContent={Text(if (cacheBytes < 0) "Tap to clear" else "Cleared ${enhancedVaultManager.getStorageUsageFormatted(0L)}")},
                        trailingContent={Text("›")},
                        modifier=Modifier.clickable {
                            val freed = enhancedVaultManager.clearCache()
                            cacheBytes = freed
                            refreshStorage()
                            Toast.makeText(context, "Freed ${if (freed >= 1024*1024) String.format("%.2f MB", freed/1024.0/1024.0) else "$freed B"}", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }
        }
        item {
            Text("Privacy", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    ListItem(
                        headlineContent={Text("App Lock")},
                        supportingContent={Text(if(securityManager.isAppLockEnabled()) "Enabled" else "Disabled")},
                        trailingContent={ Switch(
                            checked=securityManager.isAppLockEnabled(),
                            onCheckedChange={ enabled ->
                                securityManager.setAppLockEnabled(enabled)
                                if (enabled && !pinSet) onSetPin()
                            }
                        ) }
                    )
                    Divider()
                    // was: Switch(checked=false, onCheckedChange={}) - a permanently dead control
                    ListItem(
                        headlineContent={Text("Biometric")},
                        supportingContent={Text(
                            when {
                                !biometricAvailable -> "Not available on this device"
                                biometricOn -> "Unlocks Schatz"
                                else -> "Tap to enable"
                            }
                        )},
                        trailingContent={ Switch(
                            checked=biometricOn,
                            enabled=biometricAvailable,
                            onCheckedChange={ on ->
                                biometricOn = on
                                securityManager.setBiometricEnabled(on)
                            }
                        ) }
                    )
                    Divider()
                    // The "End-to-end" label on this row was a false security claim: the switch did
                    // nothing and the vault is plain files. Replaced with what is actually true.
                    ListItem(
                        headlineContent={Text("Vault at rest")},
                        supportingContent={Text("App-private storage, not encrypted")}
                    )
                }
            }
        }
        item {
            Text("Appearance", style=MaterialTheme.typography.labelSmall)
            Card { ListItem(headlineContent={Text("Dark Mode")}, trailingContent={ Switch(checked=isDark, onCheckedChange={onToggleDark()}) }) }
        }
        item {
            Text("About", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    // Was hardcoded to "12.2-full" while the build declares 12.0-production.
                    ListItem(headlineContent={Text("App Version")}, supportingContent={Text(BuildConfig.VERSION_NAME)})
                    Divider()
                    ListItem(headlineContent={Text("TDLib Version")}, supportingContent={Text("1.8.45")})
                }
            }
        }
        }
    }
}

@Composable
fun CallScreen(callManager: CallManager, partnerName: String = "Her") {
    val callState by callManager.callState.collectAsState()
    val duration by callManager.duration.collectAsState()
    val isMuted by callManager.isMuted.collectAsState()
    val isSpeaker by callManager.isSpeaker.collectAsState()
    val isVideo by callManager.isVideoEnabled.collectAsState()
    val lastError by callManager.lastError.collectAsState()
    val isRinging = callState == CallState.INCOMING || callState == CallState.RINGING
    val isFailed = callState == CallState.FAILED || callState == CallState.BUSY
    val initial = partnerName.trim().firstOrNull()?.uppercase() ?: "?"

    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement=Arrangement.Center, horizontalAlignment=Alignment.CenterHorizontally) {
        Surface(shape=RoundedCornerShape(28.dp), color=MaterialTheme.colorScheme.primary, modifier=Modifier.size(96.dp)) { Box(contentAlignment=Alignment.Center) { Text(initial, style=MaterialTheme.typography.headlineLarge, color=MaterialTheme.colorScheme.onPrimary) } }
        Spacer(Modifier.height(16.dp))
        Text(partnerName, style=MaterialTheme.typography.titleLarge)
        Text(
            text = when(callState) {
                CallState.CALLING -> "Calling..."
                CallState.INCOMING, CallState.RINGING -> "Incoming ${if (isVideo) "video" else "voice"} call"
                CallState.CONNECTING -> "Connecting..."
                CallState.CONNECTED -> "${duration/60}:${(duration%60).toString().padStart(2,'0')} • Private"
                CallState.ENDED -> "Ended"
                CallState.DECLINED -> "Declined"
                CallState.MISSED -> "Missed"
                // The real TDLib reason (e.g. "USER_NOT_FOUND") replaces the bare "Call failed".
                CallState.FAILED -> lastError?.let { "Call failed: $it" } ?: "Call failed"
                CallState.BUSY -> "Busy"
                // Never render the raw enum name.
                else -> "..."
            },
            style=MaterialTheme.typography.bodySmall,
            color=if (isFailed) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
        )

        Spacer(Modifier.height(40.dp))

        if (isRinging) {
            // Without these two buttons an incoming call could never be answered or rejected.
            Row(horizontalArrangement=Arrangement.spacedBy(24.dp)) {
                FilledTonalButton(onClick={callManager.declineCall()}, colors=ButtonDefaults.filledTonalButtonColors(containerColor=MaterialTheme.colorScheme.errorContainer)) { Text("Decline") }
                Button(onClick={callManager.acceptCall()}, shape=RoundedCornerShape(20.dp)) { Text("Answer") }
            }
        } else if (isFailed) {
            // A failed call is terminal: only a Close that returns to the chat, no mute/end.
            if (lastError != null) {
                Text(
                    lastError!!,
                    style=MaterialTheme.typography.labelSmall,
                    color=MaterialTheme.colorScheme.error,
                    textAlign=androidx.compose.ui.text.style.TextAlign.Center,
                    modifier=Modifier.padding(horizontal=16.dp)
                )
                Spacer(Modifier.height(12.dp))
            }
            Button(onClick={callManager.reset()}, shape=RoundedCornerShape(20.dp), modifier=Modifier.fillMaxWidth(0.9f)) { Text("Close") }
        } else {
            Row(horizontalArrangement=Arrangement.spacedBy(20.dp)) {
                FilledTonalButton(onClick={callManager.toggleMute()}) { Text(if(isMuted) "Unmute" else "Mute") }
                FilledTonalButton(onClick={callManager.toggleSpeaker()}) { Text(if(isSpeaker) "Earpiece" else "Speaker") }
            }
            Spacer(Modifier.height(20.dp))
            Button(onClick={callManager.endCall()}, shape=RoundedCornerShape(20.dp), modifier=Modifier.fillMaxWidth(0.9f), colors=ButtonDefaults.buttonColors(containerColor=MaterialTheme.colorScheme.error)) { Text("End") }
        }
    }
}

