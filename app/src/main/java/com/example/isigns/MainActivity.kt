package com.example.isigns

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.example.isigns.data.UserProgressRepository
import com.example.isigns.ui.screens.SignDetailScreen
import com.example.isigns.ui.screens.SignsScreen
import com.example.isigns.ui.screens.TranslateScreen
import com.example.isigns.ui.theme.ISignsTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        UserProgressRepository.initialize(this)
        setContent {
            ISignsTheme {
                ISignsApp()
            }
        }
    }
}

enum class Tab(val label: String, val selectedIcon: ImageVector, val unselectedIcon: ImageVector) {
    Translate("Translate", Icons.Filled.Translate, Icons.Outlined.Translate),
    Signs("Signs", Icons.Filled.MenuBook, Icons.Outlined.MenuBook),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ISignsApp() {
    var selectedTab by remember { mutableStateOf(Tab.Signs) }
    var detailSignId by remember { mutableStateOf<Int?>(null) }

    if (detailSignId != null) {
        SignDetailScreen(
            signId = detailSignId!!,
            onBack = { detailSignId = null },
        )
        return
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                Tab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = {
                            Icon(
                                imageVector = if (selectedTab == tab) tab.selectedIcon else tab.unselectedIcon,
                                contentDescription = tab.label,
                            )
                        },
                        label = { Text(tab.label) },
                    )
                }
            }
        },
    ) { innerPadding ->
        when (selectedTab) {
            Tab.Translate -> TranslateScreen(
                onSignClick = { detailSignId = it.id },
                modifier = Modifier.padding(innerPadding),
            )
            Tab.Signs -> SignsScreen(
                onSignClick = { detailSignId = it.id },
                modifier = Modifier.padding(innerPadding),
            )
        }
    }
}


