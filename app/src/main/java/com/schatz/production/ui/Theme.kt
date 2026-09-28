package com.schatz.production.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(primary = Color(0xFF111111), onPrimary = Color.White, background = Color(0xFFFCFCF9), surface = Color.White, onSurface = Color(0xFF111111), surfaceVariant = Color(0xFFEDE8E3), outline = Color(0xFFEDE8E3))
private val DarkColors = darkColorScheme(primary = Color.White, onPrimary = Color(0xFF0F0F0E), background = Color(0xFF0F0F0E), surface = Color(0xFF1A1A18), onSurface = Color(0xFFEAE8E3), surfaceVariant = Color(0xFF252420), outline = Color(0xFF252420))

@Composable
fun SchatzTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable ()->Unit) {
    MaterialTheme(colorScheme = if(darkTheme) DarkColors else LightColors, content = content)
}
