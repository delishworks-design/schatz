package com.schatz.production.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import coil.compose.AsyncImage
import java.io.File

/**
 * Full-screen media viewer: pinch-free fit-to-screen photo via Coil, or video via Media3
 * ExoPlayer. The player is always released on dismiss - a leaked ExoPlayer keeps the camera/
 * decoder socket alive and shows up as a stuck media session.
 */
@Composable
fun MediaViewer(path: String, isVideo: Boolean, onDismiss: () -> Unit) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)
    ) {
        Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
            if (isVideo) {
                val context = LocalContext.current
                val player = remember(path) {
                    ExoPlayer.Builder(context).build().apply {
                        // File.toURI().toString() -> "file:///..." which ExoPlayer resolves
                        // directly; androidx.core.net.toUri is not on this classpath.
                        setMediaItem(MediaItem.fromUri(File(path).toURI().toString()))
                        prepare()
                        playWhenReady = true
                    }
                }
                DisposableEffect(Unit) { onDispose { player.release() } }
                AndroidView(
                    factory = { viewContext ->
                        PlayerView(viewContext).apply {
                            useController = true
                            this.player = player
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                AsyncImage(
                    model = File(path),
                    contentDescription = "Photo",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable(onClick = onDismiss)
                )
            }

            TextButton(
                onClick = onDismiss,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
            ) {
                Text("✕", color = Color.White)
            }
        }
    }
}
