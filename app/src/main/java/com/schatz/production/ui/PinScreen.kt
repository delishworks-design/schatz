package com.schatz.production.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.schatz.production.managers.AutoLockManager
import com.schatz.production.managers.SecurityManager

/**
 * The lock screen shown after auto-lock. This lived in the old FinalScreens.kt (deleted as dead
 * code) - it is the one screen from that file that is still referenced by SchatzApp.
 */
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
