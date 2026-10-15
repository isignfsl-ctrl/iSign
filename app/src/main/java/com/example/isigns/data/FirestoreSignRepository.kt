package com.example.isigns.data

import com.example.isigns.model.Sign
import com.example.isigns.model.SignCatalogEntry
import com.example.isigns.model.toSign
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.tasks.await

object FirestoreSignRepository {
    private val firestore = FirebaseFirestore.getInstance()
    private val collection = firestore.collection("signs")

    fun getSigns(): Flow<List<Sign>> = flow {
        try {
            val snapshot = collection
                .orderBy("signId")
                .get()
                .await()
            val signs = snapshot.documents.mapNotNull { doc ->
                doc.data?.let { SignCatalogEntry.fromFirestore(doc.id, it).toSign() }
            }
            emit(signs)
        } catch (e: Exception) {
            emit(emptyList())
        }
    }

    fun getSignsByCategory(categoryId: Int): Flow<List<Sign>> = flow {
        try {
            val snapshot = collection
                .whereEqualTo("categoryId", categoryId)
                .orderBy("signId")
                .get()
                .await()
            val signs = snapshot.documents.mapNotNull { doc ->
                doc.data?.let { SignCatalogEntry.fromFirestore(doc.id, it).toSign() }
            }
            emit(signs)
        } catch (e: Exception) {
            emit(emptyList())
        }
    }

    fun searchSigns(query: String): Flow<List<Sign>> = flow {
        if (query.isBlank()) {
            emit(emptyList())
            return@flow
        }
        try {
            val q = query.lowercase()
            val snapshot = collection
                .orderBy("signName")
                .get()
                .await()
            val signs = snapshot.documents.mapNotNull { doc ->
                doc.data?.let { SignCatalogEntry.fromFirestore(doc.id, it).toSign() }
            }.filter { sign ->
                sign.name.lowercase().contains(q) ||
                sign.description.lowercase().contains(q) ||
                sign.category.lowercase().contains(q) ||
                sign.handshape.lowercase().contains(q) ||
                sign.movement.lowercase().contains(q)
            }
            emit(signs)
        } catch (e: Exception) {
            emit(emptyList())
        }
    }

    suspend fun getSignById(id: Int): Sign? {
        return try {
            val snapshot = collection
                .whereEqualTo("signId", id)
                .get()
                .await()
            snapshot.documents.firstOrNull()?.data?.let {
                SignCatalogEntry.fromFirestore(snapshot.documents.first().id, it).toSign()
            }
        } catch (e: Exception) {
            null
        }
    }
}
