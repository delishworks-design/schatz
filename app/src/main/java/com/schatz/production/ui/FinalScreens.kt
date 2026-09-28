package com.schatz.production.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.schatz.production.managers.*

@Composable
@OptIn(ExperimentalLayoutApi::class)
fun VaultFinalScreen(enhancedVaultManager: EnhancedVaultManager, myId: Long) {
    val personalFiles by enhancedVaultManager.personalFiles.collectAsState()
    val download = rememberVaultDownloader()
    val sharedFiles by enhancedVaultManager.sharedFiles.collectAsState()
    val searchQuery by enhancedVaultManager.searchQuery.collectAsState()
    val sortBy by enhancedVaultManager.sortBy.collectAsState()
    val viewMode by enhancedVaultManager.viewMode.collectAsState()
    val storageUsage by enhancedVaultManager.storageUsage.collectAsState()

    var showCreateFolderDialog by remember { mutableStateOf(false) }
    var showFileDetails by remember { mutableStateOf<EnhancedVaultFile?>(null) }
    var showImagePreview by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(myId) { if(myId != 0L) enhancedVaultManager.loadVaults(myId) }

    Column(Modifier.fillMaxSize()) {
        // Search + Sort + View toggle + Storage
        Column(Modifier.padding(12.dp), verticalArrangement=Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value=searchQuery, onValueChange={enhancedVaultManager.setSearchQuery(it, myId)}, placeholder={Text("Search vault...")}, modifier=Modifier.fillMaxWidth(), shape=RoundedCornerShape(12.dp))

            Row(Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.End, verticalAlignment=Alignment.CenterVertically) {
                Text(enhancedVaultManager.getStorageUsageFormatted(myId), style=MaterialTheme.typography.labelSmall)
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.SpaceBetween) {
                Row(horizontalArrangement=Arrangement.spacedBy(4.dp)) {
                    FilterChip(selected=sortBy==SortBy.DATE, onClick={enhancedVaultManager.setSortBy(SortBy.DATE, myId)}, label={Text("Date")})
                    FilterChip(selected=sortBy==SortBy.NAME, onClick={enhancedVaultManager.setSortBy(SortBy.NAME, myId)}, label={Text("Name")})
                    FilterChip(selected=sortBy==SortBy.SIZE, onClick={enhancedVaultManager.setSortBy(SortBy.SIZE, myId)}, label={Text("Size")})
                }
                Row(horizontalArrangement=Arrangement.spacedBy(4.dp)) {
                    IconButton(onClick={enhancedVaultManager.setViewMode(ViewMode.GRID)}) { Text("⊞") }
                    IconButton(onClick={enhancedVaultManager.setViewMode(ViewMode.LIST)}) { Text("☰") }
                    IconButton(onClick={showCreateFolderDialog=true}) { Text("📁+") }
                }
            }
        }

        val vaultFiles = personalFiles + sharedFiles

        LazyColumn(Modifier.fillMaxSize().padding(12.dp), verticalArrangement=Arrangement.spacedBy(16.dp)) {
            vaultSection("Media", vaultFiles.filter { it.type == VaultType.IMAGE }, viewMode, 200.dp,
                onOpen={ file -> if(file.type == VaultType.IMAGE) showImagePreview = file.path else showFileDetails = file },
                onLongPress={ file -> showFileDetails = file })
            vaultSection("Videos", vaultFiles.filter { it.type == VaultType.VIDEO }, viewMode, 160.dp,
                onOpen={ file -> showFileDetails = file },
                onLongPress={ file -> showFileDetails = file })
            vaultSection("Files", vaultFiles.filter { it.type == VaultType.DOCUMENT || it.type == VaultType.OTHER }, viewMode, 200.dp,
                onOpen={ file -> showFileDetails = file },
                onLongPress={ file -> showFileDetails = file })
        }

        // File details dialog
        showFileDetails?.let { file ->
            AlertDialog(onDismissRequest={showFileDetails=null}, title={Text(file.name)}, text={
                Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
                    Text("Size: ${file.size/1024} KB")
                    Text("Type: ${file.type}")
                    Text("Path: ${file.path}")
                    Text("Date: ${java.text.SimpleDateFormat("MMM dd, yyyy HH:mm").format(java.util.Date(file.timestamp))}")
                    Text("Owner: ${if(file.isShared) "Shared" else "Only you"}")
                    FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                        Button(onClick={showFileDetails=null; showImagePreview=file.path}) {Text("Preview")}
                        OutlinedButton(onClick={ download(file.path) }) {Text("Download")}
                        OutlinedButton(onClick={enhancedVaultManager.deleteFile(file.id, file.isShared, myId); showFileDetails=null}) {Text("Delete")}
                    }
                }
            }, confirmButton={ TextButton(onClick={showFileDetails=null}){Text("Close")} })
        }

        // Create folder dialog
        if(showCreateFolderDialog) {
            var folderName by remember { mutableStateOf("") }
            AlertDialog(onDismissRequest={showCreateFolderDialog=false}, title={Text("Create Folder")}, text={
                OutlinedTextField(value=folderName, onValueChange={folderName=it}, placeholder={Text("Folder name")})
            }, confirmButton={ Button(onClick={if(folderName.isNotBlank()){enhancedVaultManager.createFolder(folderName, true, myId); showCreateFolderDialog=false}}){Text("Create")} }, dismissButton={ TextButton(onClick={showCreateFolderDialog=false}){Text("Cancel")} })
        }
    }
}

private fun LazyListScope.vaultSection(
    title: String,
    files: List<EnhancedVaultFile>,
    viewMode: ViewMode,
    gridHeight: Dp,
    onOpen: (EnhancedVaultFile) -> Unit,
    onLongPress: (EnhancedVaultFile) -> Unit
) {
    item {
        Text(title, style=MaterialTheme.typography.labelMedium)
        Spacer(Modifier.height(8.dp))
    }
    if(files.isEmpty()) {
        item { Text("Nothing here yet", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurface.copy(alpha=0.6f)) }
        return
    }
    if(viewMode == ViewMode.GRID) {
        item {
            LazyVerticalGrid(columns=GridCells.Fixed(3), modifier=Modifier.height(gridHeight), horizontalArrangement=Arrangement.spacedBy(6.dp), verticalArrangement=Arrangement.spacedBy(6.dp)) {
                items(files) { file ->
                    Surface(shape=RoundedCornerShape(12.dp), color=MaterialTheme.colorScheme.surfaceVariant, modifier=Modifier.aspectRatio(1f).combinedClickable(onClick={onOpen(file)}, onLongClick={onLongPress(file)})) {
                        Box(contentAlignment=Alignment.Center, modifier=Modifier.fillMaxSize()) {
                            Column(horizontalAlignment=Alignment.CenterHorizontally) {
                                Text(when(file.type){VaultType.IMAGE->"🖼️"; VaultType.VIDEO->"🎬"; VaultType.DOCUMENT->"📄"; else->"📦"})
                                Text(file.name.take(10), style=MaterialTheme.typography.labelSmall)
                            }
                        }
                    }
                }
            }
        }
    } else {
        items(files) { file ->
            ListItem(
                headlineContent={Text(file.name)},
                supportingContent={Text("${file.size/1024} KB • ${java.text.SimpleDateFormat("MMM dd").format(java.util.Date(file.timestamp))}")},
                leadingContent={ Surface(shape=RoundedCornerShape(8.dp), color=MaterialTheme.colorScheme.primary, modifier=Modifier.size(36.dp)) { Box(contentAlignment=Alignment.Center){Text(file.name.substringAfterLast('.', "").take(3).uppercase(), color=MaterialTheme.colorScheme.onPrimary, style=MaterialTheme.typography.labelSmall)} } },
                modifier=Modifier.combinedClickable(onClick={onOpen(file)}, onLongClick={onLongPress(file)})
            )
            Divider()
        }
    }
}

@Composable
fun ChatFinalScreen(tdLib: TdLibUpdateManager, connectionManager: ConnectionManager) {
    var chatManager by remember { mutableStateOf<ChatManager?>(null) }
    val privateChat by connectionManager.privateChat.collectAsState()
    var showSearch by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }

    LaunchedEffect(privateChat) {
        if(privateChat!=null && connectionManager.myId!=0L) {
            val m=ChatManager(tdLib); m.init(connectionManager.myId, privateChat!!.id); chatManager=m
        }
    }

    val messages = chatManager?.messages?.collectAsState()?.value ?: emptyList()
    val filteredMessages = if(searchQuery.isBlank()) messages else messages.filter{it.text.contains(searchQuery, ignoreCase=true)}
    var selectedMessage by remember { mutableStateOf<com.schatz.production.models.ChatMessage?>(null) }
    var showLongPressMenu by remember { mutableStateOf(false) }
    var text by remember { mutableStateOf("") }

    Column(Modifier.fillMaxSize()) {
        if(showSearch) {
            Row(Modifier.padding(12.dp).fillMaxWidth(), verticalAlignment=Alignment.CenterVertically) {
                OutlinedTextField(value=searchQuery, onValueChange={searchQuery=it}, placeholder={Text("Search messages...")}, modifier=Modifier.weight(1f))
                IconButton(onClick={showSearch=false; searchQuery=""}){Text("✕")}
            }
        }

        LazyColumn(Modifier.weight(1f).padding(16.dp), verticalArrangement=Arrangement.spacedBy(8.dp), reverseLayout=true) {
            items(filteredMessages.reversed()) { msg ->
                Row(Modifier.fillMaxWidth().combinedClickable(onClick={}, onLongClick={selectedMessage=msg; showLongPressMenu=true}), horizontalArrangement=if(msg.fromMe) Arrangement.End else Arrangement.Start) {
                    Surface(shape=RoundedCornerShape(18.dp), color=if(msg.fromMe) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant) {
                        Text(msg.text, modifier=Modifier.padding(12.dp,8.dp), color=if(msg.fromMe) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                    }
                }
            }
        }

        Row(Modifier.padding(12.dp).fillMaxWidth(), verticalAlignment=Alignment.CenterVertically) {
            IconButton(onClick={showSearch=true}){Text("🔍")}
            OutlinedTextField(value=text, onValueChange={text=it}, placeholder={Text("Message...")}, modifier=Modifier.weight(1f), shape=RoundedCornerShape(20.dp))
            Button(onClick={if(text.isNotBlank()){chatManager?.sendMessage(text); text=""}}, shape=RoundedCornerShape(12.dp)){Text("↑")}
        }

        // Long-press menu
        if(showLongPressMenu && selectedMessage!=null) {
            AlertDialog(onDismissRequest={showLongPressMenu=false}, title={Text("Message options")}, text={
                Column {
                    TextButton(onClick={text="> ${selectedMessage!!.text}\n"; showLongPressMenu=false}, modifier=Modifier.fillMaxWidth()){Text("Reply")}
                    TextButton(onClick={text=selectedMessage!!.text; showLongPressMenu=false}, modifier=Modifier.fillMaxWidth()){Text("Copy")}
                    if(selectedMessage!!.fromMe) {
                        TextButton(onClick={chatManager?.deleteMessage(selectedMessage!!.id, true); showLongPressMenu=false}, modifier=Modifier.fillMaxWidth()){Text("Delete for both")}
                    }
                }
            }, confirmButton={ TextButton(onClick={showLongPressMenu=false}){Text("Close")} })
        }
    }
}

@Composable
fun SettingsFinalScreen(securityManager: SecurityManager, autoLockManager: AutoLockManager, isDark: Boolean, onToggleDark:()->Unit) {
    var showLicenses by remember { mutableStateOf(false) }
    var fontSize by remember { mutableStateOf(securityManager.getSession("font_size") ?: "Medium") }
    var hidePreview by remember { mutableStateOf(securityManager.getSession("hide_preview")=="true") }
    var screenshotProtection by remember { mutableStateOf(securityManager.getSession("screenshot_protection")=="true") }
    var autoLockTimeout by remember { mutableStateOf(autoLockManager.timeout.value) }

    LazyColumn(Modifier.padding(16.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
        item {
            Text("Account", style=MaterialTheme.typography.labelSmall)
            Card(shape=RoundedCornerShape(16.dp)) {
                Column {
                    ListItem(headlineContent={Text("Phone")}, supportingContent={Text("+63 9XX XXX XXXX")})
                    Divider()
                    ListItem(headlineContent={Text("Logout")}, supportingContent={Text("Clear session")})
                }
            }
        }
        item {
            Text("Data and Storage", style=MaterialTheme.typography.labelSmall)
            Card(shape=RoundedCornerShape(16.dp)) {
                Column {
                    ListItem(headlineContent={Text("Storage Usage")}, supportingContent={Text("Real usage calculated")})
                    Divider()
                    ListItem(headlineContent={Text("Downloads")}, supportingContent={Text("Manage downloaded files")})
                    Divider()
                    ListItem(headlineContent={Text("Clear Cache")}, supportingContent={Text("Clear temporary files")})
                }
            }
        }
        item {
            Text("Privacy & Security", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    ListItem(headlineContent={Text("App Lock")}, trailingContent={Switch(checked=securityManager.isAppLockEnabled(), onCheckedChange={securityManager.setAppLockEnabled(it)})})
                    Divider()
                    ListItem(headlineContent={Text("Auto-Lock")}, supportingContent={Text(autoLockTimeout.name)}, trailingContent={Text("›")})
                    Divider()
                    ListItem(headlineContent={Text("Hide Message Preview")}, supportingContent={Text("Hide content in notifications")}, trailingContent={Switch(checked=hidePreview, onCheckedChange={hidePreview=it; securityManager.saveSession("hide_preview", it.toString())})})
                    Divider()
                    ListItem(headlineContent={Text("Screenshot Protection")}, supportingContent={Text("Block screenshots in vault")}, trailingContent={Switch(checked=screenshotProtection, onCheckedChange={screenshotProtection=it; securityManager.saveSession("screenshot_protection", it.toString())})})
                    Divider()
                    ListItem(headlineContent={Text("Encrypt Vault")}, trailingContent={Switch(checked=securityManager.isEncryptionEnabled(), onCheckedChange={})})
                }
            }
        }
        item {
            Text("Appearance", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    ListItem(headlineContent={Text("Dark Mode")}, trailingContent={Switch(checked=isDark, onCheckedChange={onToggleDark()})})
                    Divider()
                    ListItem(headlineContent={Text("Font Size")}, supportingContent={Text(fontSize)}, trailingContent={Text("›")})
                }
            }
        }
        item {
            Text("Notifications", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    ListItem(headlineContent={Text("Sound")}, trailingContent={Switch(checked=true, onCheckedChange={})})
                    Divider()
                    ListItem(headlineContent={Text("Vibration")}, trailingContent={Switch(checked=true, onCheckedChange={})})
                    Divider()
                    ListItem(headlineContent={Text("Badge")}, trailingContent={Switch(checked=true, onCheckedChange={})})
                }
            }
        }
        item {
            Text("About", style=MaterialTheme.typography.labelSmall)
            Card {
                Column {
                    ListItem(headlineContent={Text("App Version")}, supportingContent={Text("13.0-100pct")})
                    Divider()
                    ListItem(headlineContent={Text("TDLib Version")}, supportingContent={Text("1.8.45")})
                    Divider()
                    ListItem(headlineContent={Text("Licenses")}, trailingContent={Text("›")}, modifier=Modifier.combinedClickable(onClick={showLicenses=true}))
                }
            }
        }
    }

    if(showLicenses) {
        AlertDialog(onDismissRequest={showLicenses=false}, title={Text("Licenses")}, text={
            LazyColumn {
                item{Text("TDLib - MIT License\nJetpack Compose - Apache 2.0\nSecurity Crypto - Apache 2.0\nBiometric - Apache 2.0") }
            }
        }, confirmButton={ TextButton(onClick={showLicenses=false}){Text("Close")} })
    }
}

@Composable
fun PinScreen(securityManager: SecurityManager, autoLockManager: AutoLockManager, onUnlock:()->Unit) {
    var pin by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement=Arrangement.Center, horizontalAlignment=Alignment.CenterHorizontally) {
        Text("Schatz Locked", style=MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(value=pin, onValueChange={pin=it; error=""}, placeholder={Text("Enter PIN")})
        Spacer(Modifier.height(8.dp))
        if(error.isNotBlank()) Text(error, color=MaterialTheme.colorScheme.error, style=MaterialTheme.typography.labelSmall)
        Spacer(Modifier.height(16.dp))
        Button(onClick={if(autoLockManager.unlock(pin)){onUnlock()} else {error="Wrong PIN"}}){Text("Unlock")}
    }
}

@Composable
fun CallFinalScreen(callManager: CallManager, enhancedCallManager: CallEnhancedManager) {
    val callState by callManager.callState.collectAsState()
    val duration by callManager.duration.collectAsState()
    val audioRoute by enhancedCallManager.audioRoute.collectAsState()
    val isBluetoothAvailable by enhancedCallManager.isBluetoothAvailable.collectAsState()
    val cameraError by enhancedCallManager.cameraError.collectAsState()
    val micError by enhancedCallManager.micError.collectAsState()

    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement=Arrangement.Center, horizontalAlignment=Alignment.CenterHorizontally) {
        Surface(shape=RoundedCornerShape(28.dp), color=MaterialTheme.colorScheme.primary, modifier=Modifier.size(96.dp)) { Box(contentAlignment=Alignment.Center){Text("H", style=MaterialTheme.typography.headlineLarge, color=MaterialTheme.colorScheme.onPrimary)} }
        Spacer(Modifier.height(16.dp))
        Text("Her", style=MaterialTheme.typography.titleLarge)
        Text("${duration/60}:${(duration%60).toString().padStart(2,'0')} • ${callState.name}", style=MaterialTheme.typography.bodySmall)

        if(cameraError!=CameraError.NONE) {
            Spacer(Modifier.height(8.dp))
            Text(enhancedCallManager.getCameraErrorMessage(), color=MaterialTheme.colorScheme.error, style=MaterialTheme.typography.labelSmall)
        }
        if(micError!=MicError.NONE) {
            Spacer(Modifier.height(8.dp))
            Text(enhancedCallManager.getMicErrorMessage(), color=MaterialTheme.colorScheme.error, style=MaterialTheme.typography.labelSmall)
        }

        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            FilledTonalButton(onClick={enhancedCallManager.setAudioRoute(if(audioRoute==AudioRoute.SPEAKER) AudioRoute.EARPIECE else AudioRoute.SPEAKER)}){Text(if(audioRoute==AudioRoute.SPEAKER) "Earpiece" else "Speaker")}
            if(isBluetoothAvailable) {
                FilledTonalButton(onClick={enhancedCallManager.setAudioRoute(if(audioRoute==AudioRoute.BLUETOOTH) AudioRoute.EARPIECE else AudioRoute.BLUETOOTH)}){Text("Bluetooth")}
            }
            FilledTonalButton(onClick={callManager.toggleMute()}){Text("Mute")}
        }
        Spacer(Modifier.height(16.dp))
        Button(onClick={callManager.endCall(); enhancedCallManager.clearErrors()}, shape=RoundedCornerShape(20.dp), modifier=Modifier.fillMaxWidth(0.9f), colors=ButtonDefaults.buttonColors(containerColor=MaterialTheme.colorScheme.error)){Text("End")}
    }
}
