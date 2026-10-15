package com.example.isigns.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.isigns.data.UserProgressRepository
import com.example.isigns.data.CombinedSignRepository
import com.example.isigns.model.Sign
import com.example.isigns.ui.components.CategoryChip
import com.example.isigns.ui.components.SignCard
import kotlinx.coroutines.launch
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignsScreen(
    onSignClick: (Sign) -> Unit,
    modifier: Modifier = Modifier,
) {
    val allSigns by CombinedSignRepository.signs.collectAsStateWithLifecycle(emptyList())
    val categories by CombinedSignRepository.categories.collectAsStateWithLifecycle(emptyList())
    var selectedCategory by remember { mutableStateOf<String?>(null) }

    val filteredSigns = remember(allSigns, selectedCategory) {
        if (selectedCategory == null) allSigns
        else allSigns.filter { it.category == selectedCategory }
    }

    Column(modifier = modifier.fillMaxSize()) {
        // Category filter chips
        if (categories.isNotEmpty()) {
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // "All" chip
                item {
                    CategoryFilterChip(
                        label = "All",
                        isSelected = selectedCategory == null,
                        onClick = { selectedCategory = null },
                    )
                }
                items(categories) { category ->
                    CategoryFilterChip(
                        label = category,
                        isSelected = selectedCategory == category,
                        onClick = { selectedCategory = category },
                    )
                }
            }
        }

        if (selectedCategory != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Category: ${selectedCategory}",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                TextButton(onClick = { selectedCategory = null }) {
                    Text("Clear")
                }
            }
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            items(filteredSigns, key = { it.id }) { sign ->
                val scope = rememberCoroutineScope()
                SignCard(
                    sign = sign,
                    onClick = { onSignClick(sign) },
                    onFavoriteClick = { signId -> scope.launch { UserProgressRepository.toggleFavorite(signId) } },
                )
            }
        }
    }
}

@Composable
private fun CategoryFilterChip(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    FilterChip(
        selected = isSelected,
        onClick = onClick,
        label = { Text(label) },
        modifier = Modifier.padding(vertical = 4.dp),
    )
}