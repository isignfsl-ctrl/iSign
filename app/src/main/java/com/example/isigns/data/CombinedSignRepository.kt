package com.example.isigns.data

import com.example.isigns.model.Sign
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map

object CombinedSignRepository {
    private val firestoreRepo = FirestoreSignRepository
    private val localRepo = LocalSignRepository

    val signs: Flow<List<Sign>> = firestoreRepo.getSigns()
        .combine(localRepo.signs) { fs: List<Sign>, ls: List<Sign> ->
            if (fs.isNotEmpty()) fs else ls
        }
        .distinctUntilChanged()

    val categories: Flow<List<String>> = signs
        .map { it.map { it.category }.distinct().sorted() }
        .distinctUntilChanged()

    fun searchSigns(query: String): Flow<List<Sign>> {
        return combine(
            firestoreRepo.searchSigns(query),
            localRepo.searchSigns(query)
        ) { fs: List<Sign>, ls: List<Sign> ->
            if (fs.isNotEmpty()) fs else ls
        }.distinctUntilChanged()
    }

    fun getSignsByCategory(category: String): Flow<List<Sign>> {
        val categoryId = when (category) {
            "Alphabet", "Greetings" -> 0
            "Common Phrases", "Questions" -> 1
            "Numbers" -> 2
            "Basic Gestures", "Actions" -> 3
            "Feelings" -> 4
            else -> -1
        }
        if (categoryId >= 0) {
            return firestoreRepo.getSignsByCategory(categoryId)
                .combine(localRepo.getSignsByCategory(category)) { fs: List<Sign>, ls: List<Sign> ->
                    if (fs.isNotEmpty()) fs else ls
                }
                .distinctUntilChanged()
        }
        return localRepo.getSignsByCategory(category)
    }

    suspend fun getSignById(id: Int): Sign? {
        val fsSign = firestoreRepo.getSignById(id)
        return fsSign ?: localRepo.getSignById(id)
    }
}

object LocalSignRepository {
    val signs: Flow<List<Sign>> = flow { emit(SignRepository.signs) }
    val categories: Flow<List<String>> = flow { emit(SignRepository.categories) }

    fun searchSigns(query: String): Flow<List<Sign>> = flow {
        if (query.isBlank()) emit(emptyList())
        else {
            val q = query.lowercase()
            emit(SignRepository.signs.filter { sign ->
                sign.name.lowercase().contains(q) ||
                sign.description.lowercase().contains(q) ||
                sign.category.lowercase().contains(q) ||
                sign.handshape.lowercase().contains(q) ||
                sign.movement.lowercase().contains(q)
            })
        }
    }

    fun getSignsByCategory(category: String): Flow<List<Sign>> = flow {
        if (category == "All" || category.isBlank()) emit(SignRepository.signs)
        else emit(SignRepository.signs.filter { it.category == category })
    }

    fun getSignById(id: Int): Sign? = SignRepository.getById(id)
}
