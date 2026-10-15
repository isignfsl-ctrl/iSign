package com.example.isigns.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.isigns.data.CombinedSignRepository
import com.example.isigns.data.UserProgressRepository
import com.example.isigns.model.Sign
import com.example.isigns.ui.components.SignVideoPlayer
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignDetailScreen(
    signId: Int,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var sign by remember { mutableStateOf<Sign?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var showVideo by remember { mutableStateOf(false) }
    var isFavorite by remember { mutableStateOf(false) }

    LaunchedEffect(signId) {
        sign = CombinedSignRepository.getSignById(signId)
        isLoading = false
    }

    LaunchedEffect(sign?.id) {
        sign?.let {
            isFavorite = UserProgressRepository.isFavorite(it.id)
            UserProgressRepository.markAsViewed(it.id)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(sign?.name ?: "") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    val scope = rememberCoroutineScope()
                    IconButton(
                        onClick = {
                            scope.launch {
                                sign?.let {
                                    isFavorite = !isFavorite
                                    UserProgressRepository.toggleFavorite(it.id)
                                }
                            }
                        }
                    ) {
                        Icon(
                            imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
                            tint = if (isFavorite) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
        modifier = modifier,
    ) { padding ->
        if (showVideo && sign?.hasVideo == true) {
            SignVideoPlayer(
                sign = sign!!,
                modifier = Modifier.fillMaxSize(),
                onDismiss = { showVideo = false },
            )
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(16.dp))

                Box(
                    modifier = Modifier
                        .size(120.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    sign?.categoryColor?.copy(alpha = 0.25f)
                                        ?: MaterialTheme.colorScheme.primary.copy(alpha = 0.25f),
                                    sign?.categoryColor?.copy(alpha = 0.05f)
                                        ?: MaterialTheme.colorScheme.primary.copy(alpha = 0.05f),
                                ),
                            )
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = sign?.name?.first()?.uppercase() ?: "",
                        style = MaterialTheme.typography.displayLarge,
                        fontWeight = FontWeight.Bold,
                        color = sign?.categoryColor ?: MaterialTheme.colorScheme.primary,
                    )

                    if (sign?.hasVideo == true) {
                        Text(
                            text = "▶",
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = sign?.categoryColor ?: MaterialTheme.colorScheme.primary,
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))

                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = sign?.categoryColor?.copy(alpha = 0.12f)
                        ?: MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                ) {
                    Text(
                        text = sign?.category ?: "",
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = sign?.categoryColor ?: MaterialTheme.colorScheme.primary,
                    )
                }

                Spacer(Modifier.height(20.dp))

                Text(
                    text = sign?.name ?: "",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Spacer(Modifier.height(16.dp))

                Text(
                    text = sign?.description ?: "",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
                )

                if (sign?.hasVideo == true) {
                    Spacer(Modifier.height(24.dp))
                    Button(
                        onClick = { showVideo = true },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = sign?.categoryColor ?: MaterialTheme.colorScheme.primary,
                        ),
                    ) {
                        Text(
                            text = "Watch Video",
                            color = androidx.compose.ui.graphics.Color.White,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))
                HorizontalDivider()
                Spacer(Modifier.height(24.dp))

                DetailRow("Handshape", sign?.handshape ?: "")
                Spacer(Modifier.height(12.dp))
                DetailRow("Movement", sign?.movement ?: "")
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}
