package com.schatz.production.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.schatz.production.managers.SecurityManager

/**
 * SecurityManager.setPin existed from the start but had no caller anywhere, so there was no way to
 * set a PIN. That made the PIN lock unusable: the gate existed with nothing to satisfy it.
 */
@Composable
fun SetPinScreen(securityManager: SecurityManager, onDone: () -> Unit, onCancel: () -> Unit) {
    var pin by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }

    val mismatch = confirm.isNotEmpty() && pin != confirm
    val tooShort = pin.isNotEmpty() && pin.length < 4

    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("Set a PIN", style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.height(8.dp))
            Text(
                "Schatz will ask for this when the app lock is on.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
            )

            Spacer(Modifier.height(24.dp))

            OutlinedTextField(
                value = pin,
                onValueChange = { pin = it.filter { c -> c.isDigit() }.take(8); error = "" },
                label = { Text("New PIN (4-8 digits)") },
                singleLine = true,
                isError = tooShort,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = confirm,
                onValueChange = { confirm = it.filter { c -> c.isDigit() }.take(8); error = "" },
                label = { Text("Confirm PIN") },
                singleLine = true,
                isError = mismatch,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.fillMaxWidth()
            )

            val message = when {
                tooShort -> "Use at least 4 digits"
                mismatch -> "The PINs do not match"
                else -> error
            }
            if (message.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(message, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
            }

            Spacer(Modifier.height(20.dp))

            Button(
                onClick = {
                    when {
                        pin.length < 4 -> error = "Use at least 4 digits"
                        pin != confirm -> error = "The PINs do not match"
                        else -> { securityManager.setPin(pin); securityManager.setAppLockEnabled(true); onDone() }
                    }
                },
                enabled = !tooShort && !mismatch && pin.isNotEmpty(),
                modifier = Modifier.fillMaxWidth()
            ) { Text("Save PIN") }

            TextButton(onClick = onCancel) { Text("Cancel") }
        }
    }
}
