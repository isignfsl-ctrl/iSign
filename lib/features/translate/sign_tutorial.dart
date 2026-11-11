import '../../data/database/db_helper.dart';
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

/// Matches a recognized sentence against the local sign catalog and returns
/// the signs it references, in reading order (see `matchSignIds` for the
/// matching rules).
///
/// For every matched sign the recorded frames are loaded — preferred from
/// approved cloud data (`reference_landmarks`), falling back to this
/// device's own recordings (`training_samples`). Signs without any
/// recording come back with `framesJson == null` so the UI can tell the
/// user to train them.
Future<List<SignTutorialItem>> matchSignTutorial(String sentence) async {
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

  // Load recorded frames for every matched sign in two queries: approved
  // cloud samples first, then this device's own recordings for the rest.
  // Both use MAX(id) GROUP BY sign_id so each sign yields exactly one row —
  // a plain LIMIT would let a sign with many recordings starve the others.
  final placeholders = List.filled(matchedIds.length, '?').join(',');
  final frameBySign = <int, Map<String, Object?>>{};

  final approved = await db.rawQuery(
    'SELECT s.sign_id, s.landmarks_json, s.handedness '
    'FROM reference_landmarks s '
    'JOIN (SELECT sign_id, MAX(id) AS mid FROM reference_landmarks '
    'WHERE sign_id IN ($placeholders) GROUP BY sign_id) x '
    'ON s.id = x.mid',
    matchedIds,
  );
  for (final r in approved) {
    frameBySign[r['sign_id'] as int] = r;
  }

  final missing = matchedIds.where((id) => !frameBySign.containsKey(id)).toList();
  if (missing.isNotEmpty) {
    final localPlaceholders = List.filled(missing.length, '?').join(',');
    final local = await db.rawQuery(
      'SELECT s.sign_id, s.landmarks_json, s.handedness '
      'FROM training_samples s '
      'JOIN (SELECT sign_id, MAX(id) AS mid FROM training_samples '
      'WHERE sign_id IN ($localPlaceholders) GROUP BY sign_id) x '
      'ON s.id = x.mid',
      missing,
    );
    for (final r in local) {
      final id = r['sign_id'] as int;
      // Keep an approved recording if one turns up for the same sign.
      frameBySign.putIfAbsent(id, () => r);
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
