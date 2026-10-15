package com.example.isigns.data

import com.example.isigns.model.Sign
import org.junit.Test
import org.junit.Assert.*

class SignRepositoryTest {

    @Test
    fun testSignsListNotEmpty() {
        val signs = SignRepository.signs
        assertTrue("Signs list should not be empty", signs.isNotEmpty())
    }

    @Test
    fun testSignsCount() {
        val signs = SignRepository.signs
        assertEquals(25, signs.size)
    }

    @Test
    fun testGetByIdExisting() {
        val sign = SignRepository.getById(1)
        assertNotNull(sign)
        assertEquals(1, sign?.id)
        assertEquals("Kamusta", sign?.name)
    }

    @Test
    fun testGetByIdNonExisting() {
        val sign = SignRepository.getById(999)
        assertNull(sign)
    }

    @Test
    fun testCategoriesCount() {
        val categories = SignRepository.categories
        assertEquals(5, categories.size)
    }

    @Test
    fun testCategoriesContent() {
        val categories = SignRepository.categories
        assertTrue(categories.contains("Greetings"))
        assertTrue(categories.contains("Numbers"))
        assertTrue(categories.contains("Questions"))
        assertTrue(categories.contains("Actions"))
        assertTrue(categories.contains("Feelings"))
    }

    @Test
    fun testAllSignsHaveRequiredFields() {
        for (sign in SignRepository.signs) {
            assertTrue("Sign id should be positive", sign.id > 0)
            assertTrue("Sign name should not be empty", sign.name.isNotEmpty())
            assertTrue("Sign category should not be empty", sign.category.isNotEmpty())
            assertTrue("Sign description should not be empty", sign.description.isNotEmpty())
            assertTrue("Sign handshape should not be empty", sign.handshape.isNotEmpty())
            assertTrue("Sign movement should not be empty", sign.movement.isNotEmpty())
        }
    }

    @Test
    fun testSignsHaveUniqueIds() {
        val ids = SignRepository.signs.map { it.id }
        val uniqueIds = ids.distinct()
        assertEquals(ids.size, uniqueIds.size)
    }

    @Test
    fun testVideoUrlsAreValid() {
        for (sign in SignRepository.signs) {
            if (sign.hasVideo) {
                assertTrue("Video URL should start with https", sign.videoUrl?.startsWith("https") == true)
            }
        }
    }

    @Test
    fun testCategoriesHaveCorrectSignCount() {
        val categoryCounts = SignRepository.signs.groupBy { it.category }.mapValues { it.value.size }
        assertEquals(5, categoryCounts["Greetings"])
        assertEquals(5, categoryCounts["Numbers"])
        assertEquals(5, categoryCounts["Questions"])
        assertEquals(5, categoryCounts["Actions"])
        assertEquals(5, categoryCounts["Feelings"])
    }
}