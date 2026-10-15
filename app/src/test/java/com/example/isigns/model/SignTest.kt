package com.example.isigns.model

import com.example.isigns.ui.theme.CategoryGreetings
import com.example.isigns.ui.theme.CategoryNumbers
import com.example.isigns.ui.theme.CategoryQuestions
import com.example.isigns.ui.theme.CategoryActions
import com.example.isigns.ui.theme.CategoryFeelings
import com.example.isigns.ui.theme.CategoryDefault
import org.junit.Test
import org.junit.Assert.*

class SignTest {

    @Test
    fun testSignCreation() {
        val sign = Sign(
            id = 1,
            name = "Kamusta",
            category = "Greetings",
            description = "Hello / How are you?",
            handshape = "Open palm",
            movement = "Wrist rotation",
            videoUrl = "https://example.com/video.mp4"
        )

        assertEquals(1, sign.id)
        assertEquals("Kamusta", sign.name)
        assertEquals("Greetings", sign.category)
        assertEquals("Hello / How are you?", sign.description)
        assertEquals("Open palm", sign.handshape)
        assertEquals("Wrist rotation", sign.movement)
        assertEquals("https://example.com/video.mp4", sign.videoUrl)
    }

    @Test
    fun testSignWithNullVideoUrl() {
        val sign = Sign(
            id = 2,
            name = "Salamat",
            category = "Greetings",
            description = "Thank you",
            handshape = "Fingertips together",
            movement = "Forward motion"
        )

        assertNull(sign.videoUrl)
        assertEquals("Salamat", sign.name)
    }

    @Test
    fun testCategoryColorGreetings() {
        val sign = Sign(1, "Test", "Greetings", "", "", "")
        assertEquals(CategoryGreetings, sign.categoryColor)
    }

    @Test
    fun testCategoryColorNumbers() {
        val sign = Sign(1, "Test", "Numbers", "", "", "")
        assertEquals(CategoryNumbers, sign.categoryColor)
    }

    @Test
    fun testCategoryColorQuestions() {
        val sign = Sign(1, "Test", "Questions", "", "", "")
        assertEquals(CategoryQuestions, sign.categoryColor)
    }

    @Test
    fun testCategoryColorActions() {
        val sign = Sign(1, "Test", "Actions", "", "", "")
        assertEquals(CategoryActions, sign.categoryColor)
    }

    @Test
    fun testCategoryColorFeelings() {
        val sign = Sign(1, "Test", "Feelings", "", "", "")
        assertEquals(CategoryFeelings, sign.categoryColor)
    }

    @Test
    fun testCategoryColorDefault() {
        val sign = Sign(1, "Test", "Unknown", "", "", "")
        assertEquals(CategoryDefault, sign.categoryColor)
    }

    @Test
    fun testHasVideoWithUrl() {
        val sign = Sign(1, "Test", "Greetings", "", "", "", videoUrl = "https://example.com/video.mp4")
        assertTrue(sign.hasVideo)
    }

    @Test
    fun testHasVideoWithoutUrl() {
        val sign = Sign(1, "Test", "Greetings", "", "", "")
        assertFalse(sign.hasVideo)
    }

    @Test
    fun testHasVideoWithEmptyUrl() {
        val sign = Sign(1, "Test", "Greetings", "", "", "", videoUrl = "")
        assertFalse("Empty string videoUrl should return false for hasVideo", sign.hasVideo)
    }
}