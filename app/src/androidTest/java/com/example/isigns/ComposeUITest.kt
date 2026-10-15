package com.example.isigns

import android.content.Context
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.core.app.ApplicationProvider
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ComposeUITest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>(MainActivity::class.java)

    @Test
    fun appLaunchesAndShowsSignsScreen() {
        composeRule.onNodeWithText("Kamusta").assertExists()
        composeRule.onNodeWithText("Salamat").assertExists()
        composeRule.onNodeWithText("Isa").assertExists()
    }

    @Test
    fun categoryFilterChipsExist() {
        composeRule.onNodeWithText("Greetings").assertExists()
        composeRule.onNodeWithText("Numbers").assertExists()
        composeRule.onNodeWithText("Questions").assertExists()
        composeRule.onNodeWithText("Actions").assertExists()
        composeRule.onNodeWithText("Feelings").assertExists()
    }

    @Test
    fun clickSignOpensDetailScreen() {
        composeRule.onNodeWithText("Kamusta").performClick()
        composeRule.onNodeWithText("Hello / How are you?").assertExists()
        composeRule.onNodeWithText("Handshape").assertExists()
        composeRule.onNodeWithText("Movement").assertExists()
    }

    @Test
    fun backButtonReturnsToSignsScreen() {
        composeRule.onNodeWithText("Kamusta").performClick()
        composeRule.onNodeWithContentDescription("Back").performClick()
        composeRule.onNodeWithText("Kamusta").assertExists()
    }

    @Test
    fun translateTabShowsSearch() {
        // Switch to Translate tab (second tab)
        composeRule.onNodeWithContentDescription("Translate").performClick()
        composeRule.onNodeWithText("Translate Words to Signs").assertExists()
        composeRule.onNodeWithText("Search signs...").assertExists()
    }

    @Test
    fun searchInTranslateFiltersResults() {
        composeRule.onNodeWithContentDescription("Translate").performClick()
        composeRule.onNodeWithText("Search signs...").performClick()
        composeRule.onNodeWithText("Search signs...").performTextInput("kamusta")
        composeRule.onNodeWithText("Kamusta").assertExists()
        composeRule.onNodeWithText("Salamat").assertDoesNotExist()
    }
}