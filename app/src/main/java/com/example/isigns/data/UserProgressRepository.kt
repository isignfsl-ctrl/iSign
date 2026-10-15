package com.example.isigns.data

import android.content.Context
import android.content.SharedPreferences
import com.example.isigns.model.Sign
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.withContext

object UserProgressRepository {
    private const val PREFS_NAME = "user_progress"
    private const val FAVORITES_KEY = "favorites"
    private const val VIEWED_KEY = "viewed_signs"
    private const val MASTERED_KEY = "mastered_signs"
    private const val LAST_VIEWED_KEY = "last_viewed_sign_id"

    private var prefs: SharedPreferences? = null

    fun initialize(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private fun getIntSet(key: String): Set<Int> {
        val stringSet: Set<String>? = prefs?.getStringSet(key, emptySet())
        return stringSet?.map { it.toInt() }?.toSet() ?: emptySet()
    }

    private suspend fun putIntSet(key: String, values: Set<Int>) {
        withContext(Dispatchers.IO) {
            val editor = prefs?.edit()
            editor?.putStringSet(key, values.map { it.toString() }.toSet())
            editor?.apply()
        }
    }

    // Favorites
    fun getFavorites(): Flow<Set<Int>> = flow {
        emit(getIntSet(FAVORITES_KEY))
    }.distinctUntilChanged()

    suspend fun toggleFavorite(signId: Int) {
        val current = getIntSet(FAVORITES_KEY).toMutableSet()
        if (current.contains(signId)) current.remove(signId) else current.add(signId)
        putIntSet(FAVORITES_KEY, current)
    }

    suspend fun isFavorite(signId: Int): Boolean = signId in getIntSet(FAVORITES_KEY)

    // Viewed signs
    fun getViewedSigns(): Flow<Set<Int>> = flow {
        emit(getIntSet(VIEWED_KEY))
    }.distinctUntilChanged()

    suspend fun markAsViewed(signId: Int) {
        val current = getIntSet(VIEWED_KEY).toMutableSet()
        current.add(signId)
        putIntSet(VIEWED_KEY, current)
    }

    suspend fun isViewed(signId: Int): Boolean = signId in getIntSet(VIEWED_KEY)

    // Mastered signs
    fun getMasteredSigns(): Flow<Set<Int>> = flow {
        emit(getIntSet(MASTERED_KEY))
    }.distinctUntilChanged()

    suspend fun toggleMastered(signId: Int) {
        val current = getIntSet(MASTERED_KEY).toMutableSet()
        if (current.contains(signId)) current.remove(signId) else current.add(signId)
        putIntSet(MASTERED_KEY, current)
    }

    suspend fun isMastered(signId: Int): Boolean = signId in getIntSet(MASTERED_KEY)

    // Last viewed sign
    fun getLastViewedSignId(): Flow<Int?> = flow {
        emit(prefs?.getInt(LAST_VIEWED_KEY, -1)?.takeIf { it != -1 })
    }.distinctUntilChanged()

    suspend fun setLastViewedSignId(signId: Int) {
        withContext(Dispatchers.IO) {
            prefs?.edit()?.putInt(LAST_VIEWED_KEY, signId)?.apply()
        }
    }

    // Progress stats
    data class ProgressStats(
        val totalSigns: Int,
        val viewedCount: Int,
        val masteredCount: Int,
        val favoriteCount: Int,
        val categoryProgress: Map<String, CategoryProgress>
    )

    data class CategoryProgress(
        val total: Int,
        val viewed: Int,
        val mastered: Int,
    )

    fun getProgressStats(allSigns: List<Sign>): Flow<ProgressStats> {
        val viewedFlow = getViewedSigns().map { it.toSet() }
        val masteredFlow = getMasteredSigns().map { it.toSet() }
        val favoritesFlow = getFavorites().map { it.toSet() }

        return combine(viewedFlow, masteredFlow, favoritesFlow) { viewed: Set<Int>, mastered: Set<Int>, favorites: Set<Int> ->
            val categoryProgress = allSigns.groupBy { it.category }.map { (category, signs) ->
                val viewedInCat = signs.count { it.id in viewed }
                val masteredInCat = signs.count { it.id in mastered }
                category to CategoryProgress(
                    total = signs.size,
                    viewed = viewedInCat,
                    mastered = masteredInCat,
                )
            }.toMap()
            ProgressStats(
                totalSigns = allSigns.size,
                viewedCount = viewed.size,
                masteredCount = mastered.size,
                favoriteCount = favorites.size,
                categoryProgress = categoryProgress,
            )
        }
    }
}