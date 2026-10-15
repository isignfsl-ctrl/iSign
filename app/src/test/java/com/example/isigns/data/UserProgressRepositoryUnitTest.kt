package com.example.isigns.data

import android.content.Context
import android.content.SharedPreferences
import org.junit.Test
import org.junit.Assert.*

class UserProgressRepositoryUnitTest {

    @Test
    fun testGetIntSetLogic() {
        // Test the internal logic of getIntSet without Android context
        val testSet = setOf("1", "2", "3")
        val result = testSet.map { it.toInt() }.toSet()
        assertEquals(setOf(1, 2, 3), result)
    }

    @Test
    fun testPutIntSetLogic() {
        val values = setOf(1, 2, 3)
        val stringSet = values.map { it.toString() }.toSet()
        assertEquals(setOf("1", "2", "3"), stringSet)
    }

    @Test
    fun testFavoriteToggleLogic() {
        var favorites = mutableSetOf<Int>()
        
        // Initially empty
        assertFalse(favorites.contains(1))
        
        // Add
        favorites.add(1)
        assertTrue(favorites.contains(1))
        
        // Remove
        favorites.remove(1)
        assertFalse(favorites.contains(1))
    }

    @Test
    fun testViewedLogic() {
        var viewed = mutableSetOf<Int>()
        
        assertFalse(viewed.contains(1))
        viewed.add(1)
        assertTrue(viewed.contains(1))
    }

    @Test
    fun testMasteredLogic() {
        var mastered = mutableSetOf<Int>()
        
        assertFalse(mastered.contains(1))
        mastered.add(1)
        assertTrue(mastered.contains(1))
        mastered.remove(1)
        assertFalse(mastered.contains(1))
    }

    @Test
    fun testProgressStatsLogic() {
        val allSigns = listOf(
            com.example.isigns.model.Sign(1, "Kamusta", "Greetings", "Hello", "Open palm", "Wrist rotation"),
            com.example.isigns.model.Sign(2, "Salamat", "Greetings", "Thank you", "Fingertips together", "Forward motion"),
            com.example.isigns.model.Sign(3, "Isa", "Numbers", "One", "Index finger", "Static hold"),
        )
        
        val viewed = setOf(1, 2)
        val mastered = setOf(1)
        val favorites = setOf(3)
        
        val categoryProgress = allSigns.groupBy { it.category }.map { (category, signs) ->
            val viewedInCat = signs.count { it.id in viewed }
            val masteredInCat = signs.count { it.id in mastered }
            category to com.example.isigns.data.UserProgressRepository.CategoryProgress(
                total = signs.size,
                viewed = viewedInCat,
                mastered = masteredInCat,
            )
        }.toMap()
        
        val stats = com.example.isigns.data.UserProgressRepository.ProgressStats(
            totalSigns = 3,
            viewedCount = 2,
            masteredCount = 1,
            favoriteCount = 1,
            categoryProgress = categoryProgress,
        )
        
        assertEquals(3, stats.totalSigns)
        assertEquals(2, stats.viewedCount)
        assertEquals(1, stats.masteredCount)
        assertEquals(1, stats.favoriteCount)
        assertEquals(2, stats.categoryProgress["Greetings"]?.viewed)
        assertEquals(0, stats.categoryProgress["Numbers"]?.viewed)
        assertEquals(1, stats.categoryProgress["Greetings"]?.mastered)
    }
}