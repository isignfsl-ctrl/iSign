import 'package:cloud_firestore/cloud_firestore.dart';

/// Keeps `catalog.approvedSampleCount` truthful.
///
/// The two sides of the system use different sign-id spaces:
///   * recordings carry the **app's** `fsl_signs` ids (e.g. 533 = "Apat"),
///   * the admin `catalog` was created with its own sequence (e.g. 154 =
///     "Apat").
///
/// Looking up the catalog by `signId` alone therefore matched nothing, so the
/// counter never moved when a recording was approved — it went stale and the
/// panel could show "Trained — 5+ approved samples" for a sign that had no
/// approved data at all, while the app (which keys off the recording ids)
/// correctly reported it as untrained.
///
/// Entries are now matched on `signId` **or** sign name, the count is
/// recomputed from scratch (idempotent — approve/reject can run in any order
/// or repeatedly), and both recording collections are considered. Failures are
/// swallowed: counter maintenance must never break an approval action.
class CatalogSync {
  const CatalogSync._();

  static Future<void> recomputeApprovedCount(
    FirebaseFirestore firestore, {
    int? signId,
    String? signName,
  }) async {
    try {
      var name = (signName ?? '').trim();

      // Fall back to the sign name recorded on the matching recording.
      if (name.isEmpty && signId != null) {
        final rec = await firestore
            .collection('recordings')
            .where('signId', isEqualTo: signId)
            .limit(1)
            .get();
        if (rec.docs.isNotEmpty) {
          name = (rec.docs.first.data()['signName'] as String? ?? '').trim();
        }
      }

      // Resolve the catalog entry by id first, then by name.
      DocumentSnapshot? cat;
      if (signId != null) {
        final byId = await firestore
            .collection('catalog')
            .where('signId', isEqualTo: signId)
            .limit(1)
            .get();
        if (byId.docs.isNotEmpty) cat = byId.docs.first;
      }
      if (cat == null && name.isNotEmpty) {
        final byName = await firestore
            .collection('catalog')
            .where('signName', isEqualTo: name)
            .limit(1)
            .get();
        if (byName.docs.isNotEmpty) cat = byName.docs.first;
      }
      if (cat == null) return;

      final catData = cat.data() as Map<String, dynamic>? ?? {};
      final catId = catData['signId'] as int?;
      final catName =
          (catData['signName'] as String? ?? '').trim().toLowerCase();

      var total = 0;
      for (final collection in ['recordings', 'user_recordings']) {
        final snap = await firestore
            .collection(collection)
            .where('status', isEqualTo: 'approved')
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final recId = data['signId'] as int?;
          final recName =
              (data['signName'] as String? ?? '').trim().toLowerCase();

          final matches = (recId != null && recId == catId) ||
              (catName.isNotEmpty &&
                  recName.isNotEmpty &&
                  recName == catName);
          if (!matches) continue;

          final frameCount = (data['frameCount'] as num?)?.toInt();
          total += (frameCount != null && frameCount > 0) ? frameCount : 1;
        }
      }

      await cat.reference.update({'approvedSampleCount': total});
    } catch (_) {
      // Best-effort — never surface into the review flow.
    }
  }
}
