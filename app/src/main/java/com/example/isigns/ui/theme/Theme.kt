package com.example.isigns.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalView

private val DarkColorScheme = darkColorScheme(
    primary = IndigoLight,
    secondary = AccentBlue,
    tertiary = AccentBlueDark,
    background = SurfaceDark,
    surface = CardDark,
    onPrimary = OnSurfaceDark,
    onSecondary = OnSurfaceDark,
    onBackground = OnSurfaceDark,
    onSurface = OnSurfaceDark,
)

private val LightColorScheme = lightColorScheme(
    primary = IndigoDark,
    secondary = AccentBlue,
    tertiary = AccentBlueDark,
    background = SurfaceLight,
    surface = CardLight,
    onPrimary = OnSurfaceLight,
    onSecondary = OnSurfaceLight,
    onBackground = OnSurfaceLight,
    onSurface = OnSurfaceLight,
)

@Composable
fun ISignsTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
