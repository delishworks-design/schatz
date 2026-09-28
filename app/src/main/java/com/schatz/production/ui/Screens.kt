package com.schatz.production.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.schatz.production.R
import com.schatz.production.managers.*
import com.schatz.production.models.*
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

@Composable
fun ChatScreen(tdLib: TdLibUpdateManager, connectionManager: ConnectionManager, voiceManager: VoiceMessageManager) {
    val connectionState by connectionManager.state.collectAsState()
    val privateChat by connectionManager.privateChat.collectAsState()
    var chatManager by remember { mutableStateOf<ChatManager?>(null) }
    var myId by remember { mutableStateOf(connectionManager.myId) }

    // Initialize ChatManager with full history/pagination when chat ready
    LaunchedEffect(privateChat, connectionManager.myId) {
        if(privateChat != null && connectionManager.myId != 0L) {
            val manager = ChatManager(tdLib)
            manager.init(connectionManager.myId, privateChat!!.id)
            chatManager = manager
            myId = connectionManager.myId
        }
    }

    val messages = chatManager?.messages?.collectAsState()?.value ?: emptyList()
    val isLoadingHistory = chatManager?.isLoadingHistory?.collectAsState()?.value ?: false
    val hasMoreHistory = chatManager?.hasMoreHistory?.collectAsState()?.value ?: true
    val dateSeparators = chatManager?.dateSeparators?.collectAsState()?.value ?: emptyMap()

    var text by remember { mutableStateOf("") }
    var replyTo by remember { mutableStateOf<Long?>(null) }

    val recordingState by voiceManager.recordingState.collectAsState()
    val recordingDuration by voiceManager.recordingDuration.collectAsState()
    val amplitudes by voiceManager.amplitudes.collectAsState()

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

        // Chat with history/pagination, date separators, scroll-to-message
        Box(Modifier.weight(1f)) {
            LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement=Arrangement.spacedBy(8.dp), reverseLayout=true) {
                items(messages.reversed()) { msg ->
                    // Date separator
                    dateSeparators[msg.id]?.let { date ->
                        Box(Modifier.fillMaxWidth().padding(vertical=8.dp), contentAlignment=Alignment.Center) {
                            Surface(shape=RoundedCornerShape(12.dp), color=MaterialTheme.colorScheme.surfaceVariant) {
                                Text(date, modifier=Modifier.padding(8.dp,4.dp), style=MaterialTheme.typography.labelSmall)
                            }
                        }
                    }

                    Row(Modifier.fillMaxWidth(), horizontalArrangement=if(msg.fromMe) Arrangement.End else Arrangement.Start) {
                        Surface(shape=RoundedCornerShape(18.dp), color=if(msg.fromMe) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant) {
                            Column(Modifier.padding(12.dp,8.dp)) {
                                // Reply preview
                                // Message content with media handling via FileManager
                                Text(msg.text, style=MaterialTheme.typography.bodyMedium, color=if(msg.fromMe) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                                Row(verticalAlignment=Alignment.CenterVertically) {
                                    Text(text=java.text.SimpleDateFormat("HH:mm").format(java.util.Date(msg.timestamp)), style=MaterialTheme.typography.labelSmall, color=(if(msg.fromMe) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface).copy(alpha=0.6f))
                                    if(msg.fromMe) {
                                        Spacer(Modifier.width(4.dp))
                                        Text(text=when(msg.status) {
                                            MessageStatus.SENDING -> "○"
                                            MessageStatus.SENT -> "✓"
                                            MessageStatus.DELIVERED -> "✓✓"
                                            MessageStatus.READ -> "✓✓"
                                            MessageStatus.FAILED -> "!"
                                        }, style=MaterialTheme.typography.labelSmall, color=MaterialTheme.colorScheme.onPrimary.copy(alpha=0.7f))
                                    }
                                }
                            }
                        }
                    }
                }

                // Pagination trigger - load more when scrolling to top
                item {
                    if(hasMoreHistory) {
                        LaunchedEffect(Unit) {
                            chatManager?.loadMoreHistory()
                        }
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

        // Composer
        Row(Modifier.padding(12.dp).fillMaxWidth(), verticalAlignment=Alignment.CenterVertically) {
            IconButton(onClick={}) { Text("+") }
            OutlinedTextField(
                value=text,
                onValueChange={text=it},
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
fun SettingsScreen(securityManager: SecurityManager, isDark: Boolean, onToggleDark:()->Unit, onBackToChat:()->Unit, onOpenCallHistory:()->Unit, onOpenVault:()->Unit) {
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
                    ListItem(headlineContent={Text("Phone Number")}, supportingContent={Text("+63 9XX XXX XXXX")}, trailingContent={Text("›")})
                    Divider()
                    ListItem(headlineContent={Text("Username")}, supportingContent={Text("@schatz_user")}, trailingContent={Text("›")})
                    Divider()
                    ListItem(headlineContent={Text("Bio")}, supportingContent={Text("Private for us two")}, trailingContent={Text("›")})
                    Divider()
                    ListItem(headlineContent={Text("Logout")}, supportingContent={Text("Clear session")}, trailingContent={Text("›")})
                }
            }
        }
        item {
            Text("Data and Storage", style=MaterialTheme.typography.labelSmall)
            Card(shape=RoundedCornerShape(16.dp)) {
                Column {
                    ListItem(headlineContent={Text("Storage Usage")}, supportingContent={Text("4.8 GB used")}, trailingContent={Text("›")})
                    Divider()
                    ListItem(headlineContent={Text("Auto-Download")}, supportingContent={Text("Photos, Videos")}, trailingContent={Text("›")})
                    Divider()
                    ListItem(headlineContent={Text("Clear Cache")}, supportingContent={Text("342 MB")}, trailingContent={Text("›")})
                }
            }
        }
        item {
            Text("Privacy", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    ListItem(headlineContent={Text("App Lock")}, supportingContent={Text(if(securityManager.isAppLockEnabled()) "Enabled" else "Disabled")}, trailingContent={ Switch(checked=securityManager.isAppLockEnabled(), onCheckedChange={securityManager.setAppLockEnabled(it)}) })
                    Divider()
                    ListItem(headlineContent={Text("Biometric")}, supportingContent={Text(if(securityManager.isBiometricAvailable()) "Available" else "Not available")}, trailingContent={ Switch(checked=false, onCheckedChange={}) })
                    Divider()
                    ListItem(headlineContent={Text("Encrypt Vault")}, supportingContent={Text("End-to-end")}, trailingContent={ Switch(checked=securityManager.isEncryptionEnabled(), onCheckedChange={}) })
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
                    ListItem(headlineContent={Text("App Version")}, supportingContent={Text("12.2-full")})
                    Divider()
                    ListItem(headlineContent={Text("TDLib Version")}, supportingContent={Text("1.8.45")})
                }
            }
        }
        }
    }
}

@Composable
fun CallScreen(callManager: CallManager) {
    val callState by callManager.callState.collectAsState()
    val duration by callManager.duration.collectAsState()
    val isMuted by callManager.isMuted.collectAsState()
    val isSpeaker by callManager.isSpeaker.collectAsState()
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement=Arrangement.Center, horizontalAlignment=Alignment.CenterHorizontally) {
        Surface(shape=RoundedCornerShape(28.dp), color=MaterialTheme.colorScheme.primary, modifier=Modifier.size(96.dp)) { Box(contentAlignment=Alignment.Center) { Text("H", style=MaterialTheme.typography.headlineLarge, color=MaterialTheme.colorScheme.onPrimary) } }
        Spacer(Modifier.height(16.dp))
        Text("Her", style=MaterialTheme.typography.titleLarge)
        Text(text=when(callState) {
            CallState.CALLING -> "Calling..."
            CallState.CONNECTING -> "Connecting..."
            CallState.CONNECTED -> "${duration/60}:${(duration%60).toString().padStart(2,'0')} • Private"
            CallState.ENDED -> "Ended"
            CallState.DECLINED -> "Declined"
            CallState.MISSED -> "Missed"
            else -> callState.name
        }, style=MaterialTheme.typography.bodySmall)
        Spacer(Modifier.height(40.dp))
        Row(horizontalArrangement=Arrangement.spacedBy(20.dp)) {
            FilledTonalButton(onClick={callManager.toggleMute()}) { Text(if(isMuted) "Unmute" else "Mute") }
            FilledTonalButton(onClick={callManager.toggleSpeaker()}) { Text(if(isSpeaker) "Earpiece" else "Speaker") }
        }
        Spacer(Modifier.height(20.dp))
        Button(onClick={callManager.endCall()}, shape=RoundedCornerShape(20.dp), modifier=Modifier.fillMaxWidth(0.9f), colors=ButtonDefaults.buttonColors(containerColor=MaterialTheme.colorScheme.error)) { Text("End") }
    }
}
