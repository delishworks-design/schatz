package com.schatz.production.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat

/**
 * The app declared RECORD_AUDIO, CAMERA and POST_NOTIFICATIONS in the manifest but never asked for
 * them, so voice recording threw a SecurityException that a catch swallowed, video never started,
 * and on Android 13+ every incoming-call notification was dropped.
 *
 * Ask once per entry into the app, after authentication, so the prompt is not thrown at a user who
 * has not signed in yet.
 */
private val REQUIRED_PERMISSIONS: Array<String> = buildList {
    add(Manifest.permission.RECORD_AUDIO)
    add(Manifest.permission.POST_NOTIFICATIONS)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(Manifest.permission.BLUETOOTH_CONNECT)
    add(Manifest.permission.CAMERA)
}.toTypedArray()

@Composable
fun RequestRuntimePermissions() {
    val context = LocalContext.current
    var requested by remember { mutableStateOf(false) }

    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { granted ->
        // The result is deliberately not acted on here: a refusal only means the matching feature
        // stays unavailable, and each screen already degrades to a disabled control.
        requested = true
    }

    LaunchedEffect(Unit) {
        if (requested) return@LaunchedEffect
        val missing = REQUIRED_PERMISSIONS.filter {
            ContextCompat.checkSelfPermission(context, it) != android.content.pm.PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) launcher.launch(missing.toTypedArray()) else requested = true
    }
}
