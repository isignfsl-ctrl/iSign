import 'package:flutter/foundation.dart';

import '../../data/database/db_helper.dart';
import '../../shared/services/sync_service.dart';
import 'sign_tutorial_matcher.dart';

/// One sign matched from a spoken sentence, together with its recorded
/// hand-frame data — the "image of what the sign looks like".
///
/// [framesJson] is the raw stored payload (`parseHandFrames` in
/// `hand_frame_player.dart` parses it); null means no recording exists for
/// this sign yet.
class SignTutorialItem {
  final int signId;
  final String signName;
  final String? framesJson;
  final String? handedness;

  const SignTutorialItem({
    required this.signId,
    required this.signName,
    this.framesJson,
    this.handedness,
  });

  bool get hasImage => framesJson != null;
}

/// Signs already checked against the cloud this app session — avoids
/// re-querying Firestore for every sentence when a sign genuinely has no
/// approved data. Only populated on SUCCESSFUL attempts, so going offline
/// mid-session doesn't permanently blind the fallback.
final Set<int> _cloudChecked = {};

/// Matches a recognized sentence against the local sign catalog and returns
/// the signs it references, in reading order (see `matchSignIds` for the
/// matching rules).
///
/// Frame data comes from, in order:
///  1. approved cloud recordings cached locally (`reference_landmarks`),
///  2. this device's own recordings (`training_samples`), and
///  3. an on-demand Firestore fetch for signs that have neither — so the
///     tutorial shows images even on a device that never ran a full sync.
///
/// Signs without any recording come back with `framesJson == null` so the
/// UI can tell the user to train them.
Future<List<SignTutorialItem>> matchSignTutorial(String sentence) async {
  try {
    return await _match(sentence);
  } catch (e) {
    // One bad lookup must never break the Translate screen — the strip
    // simply doesn't appear for this sentence.
    debugPrint('Sign tutorial lookup failed: $e');
    return const [];
  }
}

Future<List<SignTutorialItem>> _match(String sentence) async {
  final db = await DbHelper().database;
  final rows = await db.query(
    'fsl_signs',
    columns: ['id', 'sign_name', 'english_name'],
  );
  if (rows.isEmpty) return const [];

  final catalog = <(int, String, String?)>[];
  final nameById = <int, String>{};
  for (final row in rows) {
    final id = row['id'] as int;
    final signName = (row['sign_name'] as String? ?? '').trim();
    final englishName = (row['english_name'] as String? ?? '').trim();
    catalog.add((id, signName, englishName));
    // Display the canonical (Filipino) sign name when available; the
    // English name is only there to also match English speech.
    nameById[id] = signName.isNotEmpty ? signName : englishName;
  }

  final matchedIds = matchSignIds(sentence, catalog);
  if (matchedIds.isEmpty) return const [];

  // Recorded frames per sign: approved cloud samples first (one row per
  // sample, MAX(id) GROUP BY sign_id so each sign yields exactly one row —
  // a plain LIMIT would let a sign with many recordings starve the others),
  // then this device's own recordings for the rest.
  final frameBySign = <int, Map<String, Object?>>{};

  Future<void> loadFrames(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    final approved = await db.rawQuery(
      'SELECT s.sign_id, s.landmarks_json, s.handedness '
      'FROM reference_landmarks s '
      'JOIN (SELECT sign_id, MAX(id) AS mid FROM reference_landmarks '
      'WHERE sign_id IN ($placeholders) GROUP BY sign_id) x '
      'ON s.id = x.mid',
      ids,
    );
    for (final r in approved) {
      frameBySign[r['sign_id'] as int] = r;
    }

    final stillMissing =
        ids.where((id) => !frameBySign.containsKey(id)).toList();
    if (stillMissing.isEmpty) return;
    final localPlaceholders =
        List.filled(stillMissing.length, '?').join(',');
    final local = await db.rawQuery(
      'SELECT s.sign_id, s.landmarks_json, s.handedness '
      'FROM training_samples s '
      'JOIN (SELECT sign_id, MAX(id) AS mid FROM training_samples '
      'WHERE sign_id IN ($localPlaceholders) GROUP BY sign_id) x '
      'ON s.id = x.mid',
      stillMissing,
    );
    for (final r in local) {
      // Keep an approved recording if one turns up for the same sign.
      frameBySign.putIfAbsent(r['sign_id'] as int, () => r);
    }
  }

  await loadFrames(matchedIds);

  // Cloud fallback: matched signs with no local data at all — fetch their
  // approved recordings on demand (rows are materialized into
  // reference_landmarks, exactly like a full sync would).
  final fetchable = matchedIds
      .where((id) =>
          !frameBySign.containsKey(id) && !_cloudChecked.contains(id))
      .toList();
  if (fetchable.isNotEmpty) {
    final names = [
      for (final id in fetchable)
        if ((nameById[id] ?? '').isNotEmpty) nameById[id]!,
    ];
    if (names.isNotEmpty) {
      // Inner try/catch: a cloud failure must not throw away the local
      // frames already matched above — the strip still renders them.
      try {
        final result = await SyncService()
            .downloadRecordingsForSigns(names)
            .timeout(const Duration(seconds: 12));
        if (result.success) {
          // Success (even with 0 rows) settles it for this session; an
          // offline failure leaves the sign eligible for retry next sentence.
          _cloudChecked.addAll(fetchable);
          if (result.synced > 0) await loadFrames(fetchable);
        }
      } catch (e) {
        debugPrint('Sign tutorial cloud fetch failed (local data kept): $e');
      }
    }
  }

  return [
    for (final id in matchedIds)
      SignTutorialItem(
        signId: id,
        signName: nameById[id] ?? '',
        framesJson: frameBySign[id]?['landmarks_json'] as String?,
        handedness: frameBySign[id]?['handedness'] as String?,
      ),
  ];
}
