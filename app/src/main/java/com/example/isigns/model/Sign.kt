package com.example.isigns.model

import androidx.compose.ui.graphics.Color
import com.example.isigns.ui.theme.*

data class Sign(
    val id: Int,
    val name: String,
    val category: String,
    val description: String,
    val handshape: String,
    val movement: String,
    val videoRes: Int? = null,
    val videoUrl: String? = null,
) {
    val categoryColor: Color
        get() = when (category) {
            "Greetings" -> CategoryGreetings
            "Numbers" -> CategoryNumbers
            "Questions" -> CategoryQuestions
            "Actions" -> CategoryActions
            "Feelings" -> CategoryFeelings
            else -> CategoryDefault
        }

    val hasVideo: Boolean
        get() = videoRes != null || (videoUrl != null && videoUrl.isNotBlank())
}
