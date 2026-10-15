package com.example.isigns.model

import com.example.isigns.ui.theme.CategoryGreetings
import com.example.isigns.ui.theme.CategoryNumbers
import com.example.isigns.ui.theme.CategoryQuestions
import com.example.isigns.ui.theme.CategoryActions
import com.example.isigns.ui.theme.CategoryFeelings
import com.example.isigns.ui.theme.CategoryDefault
import java.util.Date
import org.junit.Test
import org.junit.Assert.*

class SignCatalogEntryTest {

    @Test
    fun testSignCatalogEntryCreation() {
        val entry = SignCatalogEntry(
            signId = 1,
            signName = "Kamusta",
            description = "Hello / How are you?",
            categoryId = 0,
            version = 1,
            landmarkSamplePaths = listOf("sample1.mp4"),
            updatedAt = Date(),
            updatedBy = "admin",
            handshape = "Open palm",
            movement = "Wrist rotation",
            videoUrl = "https://example.com/video.mp4"
        )

        assertEquals(1, entry.signId)
        assertEquals("Kamusta", entry.signName)
        assertEquals("Hello / How are you?", entry.description)
        assertEquals(0, entry.categoryId)
        assertEquals(1, entry.version)
        assertEquals(listOf("sample1.mp4"), entry.landmarkSamplePaths)
        assertEquals("admin", entry.updatedBy)
        assertEquals("Open palm", entry.handshape)
        assertEquals("Wrist rotation", entry.movement)
        assertEquals("https://example.com/video.mp4", entry.videoUrl)
    }

    @Test
    fun testCategoryMapping() {
        // Test admin categoryId to app category mapping
        assertEquals("Alphabet", SignCatalogEntry(categoryId = 0).category)
        assertEquals("Common Phrases", SignCatalogEntry(categoryId = 1).category)
        assertEquals("Numbers", SignCatalogEntry(categoryId = 2).category)
        assertEquals("Basic Gestures", SignCatalogEntry(categoryId = 3).category)
        assertEquals("Category 99", SignCatalogEntry(categoryId = 99).category)
    }

    @Test
    fun testLegacyCategoryMapping() {
        // Test legacy category mapping for backward compatibility
        // Admin categories: 0=Alphabet, 1=Common Phrases, 2=Numbers, 3=Basic Gestures
        // Legacy mapping: 0->Greetings, 1->Questions, 2->Numbers, 3->Actions, else->Feelings
        assertEquals("Greetings", SignCatalogEntry(categoryId = 0).legacyCategory)
        assertEquals("Questions", SignCatalogEntry(categoryId = 1).legacyCategory)
        assertEquals("Numbers", SignCatalogEntry(categoryId = 2).legacyCategory)
        assertEquals("Actions", SignCatalogEntry(categoryId = 3).legacyCategory)
        assertEquals("Feelings", SignCatalogEntry(categoryId = 99).legacyCategory)
    }

    @Test
    fun testLegacyCategoryColor() {
        // Test categoryColor based on legacyCategory
        // 0->Greetings, 1->Questions, 2->Numbers, 3->Actions, 99->Feelings
        assertEquals(CategoryGreetings, SignCatalogEntry(categoryId = 0).categoryColor)
        assertEquals(CategoryNumbers, SignCatalogEntry(categoryId = 2).categoryColor)
        assertEquals(CategoryQuestions, SignCatalogEntry(categoryId = 1).categoryColor)
        assertEquals(CategoryActions, SignCatalogEntry(categoryId = 3).categoryColor)
        assertEquals(CategoryFeelings, SignCatalogEntry(categoryId = 99).categoryColor)
    }

    @Test
    fun testToFirestore() {
        val entry = SignCatalogEntry(
            signId = 1,
            signName = "Kamusta",
            description = "Hello",
            categoryId = 0,
            version = 1,
            landmarkSamplePaths = listOf("sample1.mp4"),
            updatedAt = Date(),
            updatedBy = "admin",
            handshape = "Open palm",
            movement = "Wrist rotation",
            videoUrl = "https://example.com/video.mp4"
        )

        val firestore = entry.toFirestore()
        assertEquals(1, firestore["signId"])
        assertEquals("Kamusta", firestore["signName"])
        assertEquals("Hello", firestore["description"])
        assertEquals(0, firestore["categoryId"])
        assertEquals(1, firestore["version"])
        assertEquals(listOf("sample1.mp4"), firestore["landmarkSamplePaths"])
        assertEquals("admin", firestore["updatedBy"])
        assertEquals("Open palm", firestore["handshape"])
        assertEquals("Wrist rotation", firestore["movement"])
        assertEquals("https://example.com/video.mp4", firestore["videoUrl"])
    }

    @Test
    fun testFromFirestore() {
        val data = mapOf(
            "signId" to 1,
            "signName" to "Kamusta",
            "description" to "Hello",
            "categoryId" to 0,
            "version" to 1,
            "landmarkSamplePaths" to listOf("sample1.mp4"),
            "updatedAt" to Date(),
            "updatedBy" to "admin",
            "handshape" to "Open palm",
            "movement" to "Wrist rotation",
            "videoUrl" to "https://example.com/video.mp4"
        )

        val entry = SignCatalogEntry.fromFirestore("doc1", data)
        assertEquals("doc1", entry.documentId)
        assertEquals(1, entry.signId)
        assertEquals("Kamusta", entry.signName)
        assertEquals("Hello", entry.description)
        assertEquals(0, entry.categoryId)
        assertEquals(1, entry.version)
        assertEquals(listOf("sample1.mp4"), entry.landmarkSamplePaths)
        assertEquals("admin", entry.updatedBy)
        assertEquals("Open palm", entry.handshape)
        assertEquals("Wrist rotation", entry.movement)
        assertEquals("https://example.com/video.mp4", entry.videoUrl)
    }

    @Test
    fun testToSignConversion() {
        val entry = SignCatalogEntry(
            signId = 1,
            signName = "Kamusta",
            description = "Hello / How are you?",
            categoryId = 0, // Greetings
            version = 1,
            landmarkSamplePaths = listOf(),
            updatedAt = Date(),
            updatedBy = "admin",
            handshape = "Open palm",
            movement = "Wrist rotation",
            videoUrl = "https://example.com/video.mp4"
        )

        val sign = entry.toSign()
        assertEquals(1, sign.id)
        assertEquals("Kamusta", sign.name)
        assertEquals("Greetings", sign.category) // legacy category
        assertEquals("Hello / How are you?", sign.description)
        assertEquals("Open palm", sign.handshape)
        assertEquals("Wrist rotation", sign.movement)
        assertEquals("https://example.com/video.mp4", sign.videoUrl)
        assertTrue(sign.hasVideo)
    }
}