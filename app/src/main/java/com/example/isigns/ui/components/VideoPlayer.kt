package com.example.isigns.ui.components

import android.content.Context
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.example.isigns.model.Sign

@OptIn(UnstableApi::class)
@Composable
fun SignVideoPlayer(
    sign: Sign,
    modifier: Modifier = Modifier,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val exoPlayer = remember { createExoPlayer(context) }
    var isPlaying by remember { mutableStateOf(false) }
    var isMuted by remember { mutableStateOf(false) }
    var showControls by remember { mutableStateOf(true) }

    LaunchedEffect(sign) {
        val mediaItem = buildMediaItem(sign, context)
        exoPlayer.setMediaItem(mediaItem)
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
        isPlaying = true
    }

    DisposableEffect(Unit) {
        onDispose {
            exoPlayer.release()
        }
    }

    LaunchedEffect(exoPlayer.playWhenReady) {
        isPlaying = exoPlayer.playWhenReady
    }

    Box(
        modifier = modifier
            .fillMaxSize()
    ) {
        AndroidPlayerView(
            player = exoPlayer,
            modifier = Modifier.fillMaxSize(),
        )

        if (showControls) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.TopEnd,
            ) {
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.padding(16.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close video",
                        tint = Color.White,
                    )
                }
            }

            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.BottomCenter,
            ) {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    shape = RoundedCornerShape(24.dp),
                    color = Color.Black.copy(alpha = 0.7f),
                ) {
                    androidx.compose.foundation.layout.Row(
                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
                        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                    ) {
                        Text(
                            text = sign.name,
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        androidx.compose.foundation.layout.Row(
                            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
                        ) {
                            IconButton(onClick = { exoPlayer.playWhenReady = !exoPlayer.playWhenReady }) {
                                Text(
                                    text = if (isPlaying) "⏸" else "▶",
                                    fontSize = 24.sp,
                                    color = Color.White,
                                )
                            }
                            IconButton(onClick = { isMuted = !isMuted; exoPlayer.volume = if (isMuted) 0f else 1f }) {
                                Icon(
                                    imageVector = if (isMuted) Icons.Default.VolumeOff else Icons.Default.VolumeUp,
                                    contentDescription = if (isMuted) "Unmute" else "Mute",
                                    tint = Color.White,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AndroidPlayerView(
    player: ExoPlayer,
    modifier: Modifier = Modifier,
) = androidx.compose.ui.viewinterop.AndroidView(
    modifier = modifier,
    factory = { ctx ->
        PlayerView(ctx).apply {
            setPlayer(player)
            useController = false
            resizeMode = androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
    },
    update = { view ->
        view.player = player
    },
)

private fun createExoPlayer(context: Context): ExoPlayer {
    return ExoPlayer.Builder(context).build()
}

private fun buildMediaItem(sign: Sign, context: Context): MediaItem {
    return when {
        sign.videoUrl != null && sign.videoUrl!!.isNotBlank() -> MediaItem.fromUri(sign.videoUrl!!)
        sign.videoRes != null -> MediaItem.fromUri("android.resource://${context.packageName}/${sign.videoRes}")
        else -> MediaItem.fromUri("android.resource://${context.packageName}/raw/placeholder")
    }
}