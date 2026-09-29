package com.schatz.production.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.schatz.production.managers.ConnectionManager
import com.schatz.production.managers.ConnectionState

/**
 * Shown until a partner has been paired. There is no implicit "first contact" fallback any more,
 * so this is the only way into the app.
 */
@Composable
fun PairPartnerScreen(connectionManager: ConnectionManager, onRetry: () -> Unit) {
    val isPairing by connectionManager.isPairing.collectAsState()
    val error by connectionManager.pairingError.collectAsState()
    val state by connectionManager.state.collectAsState()
    var input by remember { mutableStateOf("") }

    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("Schatz", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(4.dp))
            Text(
                "Connect the account of the person you share this with.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(24.dp))

            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                label = { Text("Telegram username or user id") },
                placeholder = { Text("@username or 123456789") },
                singleLine = true,
                isError = !error.isNullOrBlank(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                enabled = !isPairing,
                modifier = Modifier.fillMaxWidth()
            )

            val errorText = error.orEmpty()
            if (errorText.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(errorText, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
            }

            Spacer(Modifier.height(20.dp))

            Button(
                onClick = { connectionManager.pair(input) { _, _ -> } },
                enabled = !isPairing && input.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) { Text(if (isPairing) "Looking up..." else "Connect") }

            Spacer(Modifier.height(4.dp))
            TextButton(onClick = onRetry, enabled = !isPairing) { Text("Retry") }

            if (state == ConnectionState.CONNECTING) {
                Spacer(Modifier.height(16.dp))
                CircularProgressIndicator()
            }

            Spacer(Modifier.height(24.dp))
            Text(
                "A username lookup only finds accounts with a public username. " +
                    "If your partner has none, ask them for their numeric user id.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                textAlign = TextAlign.Center
            )
        }
    }
}
