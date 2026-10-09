import 'dart:math';
import '../data/database/db_helper.dart';
import '../data/repositories/training_repository.dart';
import '../shared/models/reference_landmark.dart';
import 'classification_result.dart';

class ReferenceMatcher {
  final _repo = TrainingRepository();
  Map<int, List<ReferenceLandmark>> _references = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final all = await _repo.getAllReferences();
    _references = {};
    for (final ref in all) {
      _references.putIfAbsent(ref.signId, () => []).add(ref);
    }
    _loaded = true;
  }

  void reload() {
    load();
  }

  /// Compare a single live frame (63 values) against all references.
  /// Returns the best matching sign and confidence, or null if no good match.
  Future<ClassificationResult?> match(List<double> liveFrame) async {
    if (!_loaded || _references.isEmpty) return null;

    double bestScore = double.infinity;
    int? bestSignId;

    for (final entry in _references.entries) {
      final signId = entry.key;
      final refs = entry.value;
      if (refs.isEmpty) continue;

      final status = await _repo.getTrainingStatus(signId);
      if (status != 'trained') continue;

      for (final ref in refs) {
        final frames = ref.frames;
        if (frames.isEmpty) continue;

        double minDist = double.infinity;
        for (final refFrame in frames) {
          if (refFrame.length < 63 || liveFrame.length < 63) continue;
          double dist = 0;
          for (int i = 0; i < 63; i++) {
            final d = liveFrame[i] - refFrame[i];
            dist += d * d;
          }
          dist = sqrt(dist / 63);
          if (dist < minDist) minDist = dist;
        }

        if (minDist < bestScore) {
          bestScore = minDist;
          bestSignId = signId;
        }
      }
    }

    if (bestSignId == null || bestScore > 0.5) return null;

    final signName = await _getSignName(bestSignId);
    if (signName == null) return null;

    final confidence = (1.0 - bestScore).clamp(0.0, 1.0);
    return ClassificationResult(label: signName, confidence: confidence);
  }

  /// Compare a sequence of frames against references using DTW.
  Future<ClassificationResult?> matchSequence(List<List<double>> buffer) async {
    if (!_loaded || _references.isEmpty || buffer.length < 5) return null;

    double bestScore = double.infinity;
    int? bestSignId;

    for (final entry in _references.entries) {
      final signId = entry.key;
      final refs = entry.value;
      if (refs.isEmpty) continue;

      final status = await _repo.getTrainingStatus(signId);
      if (status != 'trained') continue;

      for (final ref in refs) {
        final refFrames = ref.frames;
        if (refFrames.length < 5) continue;

        final score = _dtwDistance(buffer, refFrames);
        if (score < bestScore) {
          bestScore = score;
          bestSignId = signId;
        }
      }
    }

    if (bestSignId == null || bestScore > 0.4) return null;

    final signName = await _getSignName(bestSignId);
    if (signName == null) return null;

    final confidence = (1.0 - bestScore * 2).clamp(0.0, 1.0);
    return ClassificationResult(label: signName, confidence: confidence);
  }

  Future<String?> _getSignName(int signId) async {
    final db = await DbHelper().database;
    final rows = await db.query('fsl_signs',
        columns: ['sign_name'],
        where: 'id = ?', whereArgs: [signId]);
    if (rows.isEmpty) return null;
    return rows.first['sign_name'] as String?;
  }

  double _dtwDistance(List<List<double>> a, List<List<double>> b) {
    final n = a.length;
    final m = b.length;
    final dtw = List.generate(n, (_) => List.filled(m, double.infinity));
    dtw[0][0] = _frameDist(a[0], b[0]);

    for (int i = 1; i < n; i++) {
      dtw[i][0] = dtw[i - 1][0] + _frameDist(a[i], b[0]);
    }
    for (int j = 1; j < m; j++) {
      dtw[0][j] = dtw[0][j - 1] + _frameDist(a[0], b[j]);
    }
    for (int i = 1; i < n; i++) {
      for (int j = 1; j < m; j++) {
        final cost = _frameDist(a[i], b[j]);
        dtw[i][j] = cost + [
          dtw[i - 1][j],
          dtw[i][j - 1],
          dtw[i - 1][j - 1],
        ].reduce(min);
      }
    }
    return dtw[n - 1][m - 1] / (n + m);
  }

  double _frameDist(List<double> a, List<double> b) {
    double sum = 0;
    final len = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sqrt(sum / len);
  }
}
