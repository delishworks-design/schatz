package com.schatz.production.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import org.drinkless.tdlib.TdApi
import com.schatz.production.managers.TdLibUpdateManager

private enum class AuthStep { PHONE, CODE, PASSWORD }

private fun codeHint(state: TdApi.AuthorizationStateWaitCode): String = when (state.codeInfo?.type) {
    is TdApi.AuthenticationCodeTypeCall -> "Tumatawag ang Telegram — sagutin ang tawag"
    is TdApi.AuthenticationCodeTypeMissedCall -> "May na-miss na tawag — susunod ang tawag"
    is TdApi.AuthenticationCodeTypeSmsPhrase -> "Iisa o dalawang salita mula sa SMS"
    is TdApi.AuthenticationCodeTypeSmsWord -> "Isang salita mula sa SMS"
    is TdApi.AuthenticationCodeTypeFlashCall -> "Flash call — buksan ang telepono"
    else -> "Kodeng ipinadala ng Telegram"
}

@Composable
fun AuthScreen(tdLib: TdLibUpdateManager) {
    val authState by tdLib.authState.collectAsState()

    val step = when (authState) {
        is TdApi.AuthorizationStateWaitCode -> AuthStep.CODE
        is TdApi.AuthorizationStateWaitPassword -> AuthStep.PASSWORD
        else -> AuthStep.PHONE
    }

    var value by remember(step) { mutableStateOf("") }
    var error by remember(step) { mutableStateOf("") }
    val hint = (authState as? TdApi.AuthorizationStateWaitCode)?.let { codeHint(it) }

    val isPhone = step == AuthStep.PHONE
    val label = when (step) {
        AuthStep.PHONE -> "Phone number"
        AuthStep.CODE -> hint ?: "Login code"
        AuthStep.PASSWORD -> "Two-step password"
    }

    fun submit() {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) { error = "Hindi pa ka na-fill"; return }
        error = ""
        when (step) {
            AuthStep.PHONE -> tdLib.sendPhone(trimmed)
            AuthStep.CODE -> tdLib.sendCode(trimmed)
            AuthStep.PASSWORD -> tdLib.sendPassword(trimmed)
        }
        value = ""
    }

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
                text = when (step) {
                    AuthStep.PHONE -> "Mag-sign in gamit ang iyong Telegram account"
                    AuthStep.CODE -> hint ?: "Enter the code Telegram sent you"
                    AuthStep.PASSWORD -> "May 2FA password ka — ilagay dito"
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(24.dp))

            OutlinedTextField(
                value = value,
                onValueChange = { value = it; error = "" },
                label = { Text(label) },
                singleLine = true,
                isError = error.isNotBlank(),
                visualTransformation = when (step) {
                    AuthStep.PASSWORD -> PasswordVisualTransformation()
                    else -> VisualTransformation.None
                },
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (isPhone) KeyboardType.Phone else KeyboardType.NumberPassword
                ),
                modifier = Modifier.fillMaxWidth()
            )

            if (error.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    error,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error
                )
            }

            Spacer(Modifier.height(20.dp))

            Button(onClick = { submit() }, modifier = Modifier.fillMaxWidth()) {
                Text(
                    when (step) {
                        AuthStep.PHONE -> "Send code"
                        AuthStep.CODE -> "Verify"
                        AuthStep.PASSWORD -> "Unlock"
                    }
                )
            }

            if (step != AuthStep.PHONE) {
                Spacer(Modifier.height(4.dp))
                TextButton(onClick = { tdLib.logout() }) { Text("Use another account") }
            }
        }
    }
}
