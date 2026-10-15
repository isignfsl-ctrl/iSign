package com.example.isigns.model

import androidx.compose.ui.graphics.Color
import com.example.isigns.ui.theme.*
import com.google.firebase.firestore.ServerTimestamp
import java.util.Date

data class SignCatalogEntry(
    val signId: Int = 0,
    val signName: String = "",
    val description: String = "",
    val categoryId: Int = 0,
    val version: Int = 1,
    val landmarkSamplePaths: List<String> = emptyList(),
    val updatedAt: Date = Date(),
    val updatedBy: String = "",
    // App-specific fields (not in admin yet)
    val handshape: String = "",
    val movement: String = "",
    val videoUrl: String? = null,
    @ServerTimestamp
    val createdAt: Date? = null,
    val documentId: String? = null, // Firestore document ID
) {
    // Map admin's categoryId to app's category names
    val category: String
        get() = when (categoryId) {
            0 -> "Alphabet"
            1 -> "Common Phrases"
            2 -> "Numbers"
            3 -> "Basic Gestures"
            else -> "Category $categoryId"
        }

    // Map to app's original 5 categories for backward compatibility
    val legacyCategory: String
        get() = when (categoryId) {
            0 -> "Greetings"      // Alphabet -> Greetings
            1 -> "Questions"      // Common Phrases -> Questions
            2 -> "Numbers"        // Numbers -> Numbers
            3 -> "Actions"        // Basic Gestures -> Actions
            else -> "Feelings"    // Default
        }

    val categoryColor: Color
        get() = when (legacyCategory) {
            "Greetings" -> CategoryGreetings
            "Numbers" -> CategoryNumbers
            "Questions" -> CategoryQuestions
            "Actions" -> CategoryActions
            "Feelings" -> CategoryFeelings
            else -> CategoryDefault
        }

    val name: String
        get() = signName

    val id: Int
        get() = signId

    val hasVideo: Boolean
        get() = videoUrl != null && videoUrl.isNotBlank()

    fun toFirestore(): Map<String, Any?> {
        return mapOf(
            "signId" to signId,
            "signName" to signName,
            "description" to description,
            "categoryId" to categoryId,
            "version" to version,
            "landmarkSamplePaths" to landmarkSamplePaths,
            "updatedAt" to updatedAt,
            "updatedBy" to updatedBy,
            "handshape" to handshape,
            "movement" to movement,
            "videoUrl" to videoUrl,
        )
    }

    companion object {
        fun fromFirestore(documentId: String, data: Map<String, Any>): SignCatalogEntry {
            return SignCatalogEntry(
                signId = data["signId"] as? Int ?: 0,
                signName = data["signName"] as? String ?: "",
                description = data["description"] as? String ?: "",
                categoryId = data["categoryId"] as? Int ?: 0,
                version = data["version"] as? Int ?: 1,
                landmarkSamplePaths = (data["landmarkSamplePaths"] as? List<Any>)?.map { it as String } ?: emptyList(),
                updatedAt = (data["updatedAt"] as? com.google.firebase.Timestamp)?.toDate() ?: Date(),
                updatedBy = data["updatedBy"] as? String ?: "",
                handshape = data["handshape"] as? String ?: "",
                movement = data["movement"] as? String ?: "",
                videoUrl = data["videoUrl"] as? String,
                createdAt = (data["createdAt"] as? com.google.firebase.Timestamp)?.toDate(),
                documentId = documentId,
            )
        }
    }
}

fun SignCatalogEntry.toSign(): Sign {
    return Sign(
        id = this.signId,
        name = this.signName,
        category = this.legacyCategory,
        description = this.description,
        handshape = if (this.handshape.isNotBlank()) this.handshape else "See video for handshape",
        movement = if (this.movement.isNotBlank()) this.movement else "See video for movement",
        videoUrl = this.videoUrl,
    )
}