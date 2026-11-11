import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../data/database/db_helper.dart';
import 'classification_result.dart';

/// One reference sequence, pre-normalized into the same wrist-centered,
/// middle-finger-scaled space as live frames.
class _RefSeq {
  final List<List<double>> frames;
  const _RefSeq(this.frames);
}

/// Matches live hand frames against recorded sign data.
///
/// Two tiers, in priority order:
///  1. approved cloud recordings (`reference_landmarks`)
///  2. this device's own recordings (`training_samples`) — so a sign the
///     user trained on this phone is recognizable even before an admin
///     approves it.
///
/// Everything heavy (JSON parsing, normalization, sign names) happens once
/// in [load]; the per-frame path is pure math with bounded work. The
/// previous implementation re-normalized every reference frame and ran two
/// SQLite queries on every camera frame — a major source of lag — and it
/// could only ever match signs already marked "trained".
class ReferenceMatcher {
  /// Set when reference data on disk changed (e.g. a sync finished).
  /// The camera loop polls this and reloads lazily.
  static bool _dataDirty = false;
  static void markDataChanged() => _dataDirty = true;
  static bool get dataDirty => _dataDirty;
  static void clearDataDirty() => _dataDirty = false;

  /// Rows loaded per sign from this device's own recordings (newest first).
  static const _maxLocalSeqsPerSign = 10;

  /// Max reference sequences evaluated per sign during DTW.
  static const _maxDtwSeqsPerSign = 8;

  /// How many top-ranked signs the cheap single-frame pass forwards to DTW.
  /// Evaluating DTW against every sign every frame was the main lag source.
  static const _dtwCandidateSigns = 5;

  /// Thresholds kept from the previous implementation so confidence values
  /// stay comparable.
  static const _singleFrameMaxDistance = 0.5;
  static const _dtwMaxDistance = 0.4;

  final Map<int, List<_RefSeq>> _approved = {};
  final Map<int, List<_RefSeq>> _local = {};
  final Map<int, String> _names = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    _dataDirty = false; // changes arriving mid-load re-set it
    try {
      final db = await DbHelper().database;

      // --- Sign names (replaces the per-frame _getSignName DB lookups).
      final names = <int, String>{};
      final nameRows = await db.query(
        'fsl_signs',
        columns: ['id', 'sign_name', 'english_name'],
      );
      for (final r in nameRows) {
        final id = r['id'] as int;
        final filipino = (r['sign_name'] as String? ?? '').trim();
        final english = (r['english_name'] as String? ?? '').trim();
        names[id] = filipino.isNotEmpty ? filipino : english;
      }

      // --- Tier 1: approved cloud recordings.
      final approved = <int, List<_RefSeq>>{};
      final refRows =
          await db.query('reference_landmarks', orderBy: 'id ASC');
      for (final r in refRows) {
        final seq = _parseNormalized(r['landmarks_json'] as String?);
        if (seq == null) continue;
        final id = r['sign_id'] as int;
        (approved[id] ??= []).add(seq);
      }

      // --- Tier 2: this device's own recordings, capped per sign so a
      // heavy recorder can't bloat the matcher.
      final local = <int, List<_RefSeq>>{};
      for (final id in names.keys) {
        final rows = await db.query(
          'training_samples',
          columns: ['landmarks_json'],
          where: 'sign_id = ?',
          whereArgs: [id],
          orderBy: 'id DESC',
          limit: _maxLocalSeqsPerSign,
        );
        for (final r in rows) {
          final seq = _parseNormalized(r['landmarks_json'] as String?);
          if (seq != null) (local[id] ??= []).add(seq);
        }
      }

      _approved
        ..clear()
        ..addAll(approved);
      _local
        ..clear()
        ..addAll(local);
      _names
        ..clear()
        ..addAll(names);
      _loaded = true;
    } catch (e) {
      debugPrint('ReferenceMatcher.load failed: $e');
      // Keep any previously loaded data instead of wiping a working matcher.
    }
  }

  Future<void> reload() => load();

  /// Full per-frame pipeline: cheap single-frame ranking of every sign,
  /// DTW refinement over the top candidates (when a temporal window is
  /// available), then tiered fallbacks.
  ///
  /// Returns null when nothing matches well enough — the caller then keeps
  /// its generic classifier result.
  Future<ClassificationResult?> matchLive(
    List<double> live,
    List<List<double>>? window,
  ) async {
    if (!_loaded || live.length < 63) return null;

    // --- Cheap pass: per-sign best single-frame distance across both
    // tiers. Also produces the DTW candidate ranking.
    final bestSingle = <int, double>{};
    var approvedBest = double.infinity;
    var approvedId = -1;
    var localBest = double.infinity;
    var localId = -1;

    void scan(Map<int, List<_RefSeq>> tier, {required bool isApproved}) {
      for (final e in tier.entries) {
        var signBest = double.infinity;
        for (final seq in e.value) {
          for (final f in seq.frames) {
            if (f.length < 63) continue;
            final d = _frameRms(live, f);
            if (d < signBest) signBest = d;
          }
        }
        if (signBest.isInfinite) continue;
        final prev = bestSingle[e.key];
        if (prev == null || signBest < prev) bestSingle[e.key] = signBest;
        if (isApproved) {
          if (signBest < approvedBest) {
            approvedBest = signBest;
            approvedId = e.key;
          }
        } else {
          if (signBest < localBest) {
            localBest = signBest;
            localId = e.key;
          }
        }
      }
    }

    scan(_approved, isApproved: true);
    scan(_local, isApproved: false);

    // --- DTW pass over the top-ranked signs only (bounded work).
    if (window != null && window.length >= 5 && bestSingle.isNotEmpty) {
      final ranked = bestSingle.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      var dtwBest = double.infinity;
      var dtwId = -1;
      for (final cand in ranked.take(_dtwCandidateSigns)) {
        final seqs = <_RefSeq>[
          ...?_approved[cand.key],
          ...?_local[cand.key],
        ];
        final count =
            seqs.length > _maxDtwSeqsPerSign ? _maxDtwSeqsPerSign : seqs.length;
        for (var i = 0; i < count; i++) {
          final frames = seqs[i].frames;
          if (frames.length < 5) continue;
          final score = _dtwDistance(window, frames);
          if (score < dtwBest) {
            dtwBest = score;
            dtwId = cand.key;
          }
        }
      }

      if (dtwId >= 0 && dtwBest <= _dtwMaxDistance) {
        final name = _names[dtwId];
        if (name != null) {
          return ClassificationResult(
            label: name,
            confidence: (1.0 - dtwBest * 2).clamp(0.0, 1.0),
          );
        }
      }
    }

    // --- Single-frame fallback: approved recordings win; this device's
    // own recordings are the fallback tier.
    if (approvedId >= 0 && approvedBest <= _singleFrameMaxDistance) {
      final name = _names[approvedId];
      if (name != null) {
        return ClassificationResult(
          label: name,
          confidence: (1.0 - approvedBest).clamp(0.0, 1.0),
        );
      }
    }
    if (localId >= 0 && localBest <= _singleFrameMaxDistance) {
      final name = _names[localId];
      if (name != null) {
        return ClassificationResult(
          label: name,
          confidence: (1.0 - localBest).clamp(0.0, 1.0),
        );
      }
    }
    return null;
  }

  /// Wrist-center + middle-finger-scale normalization — identical to
  /// [TfliteClassifier.normalizeLandmarks] and the model training pipeline.
  /// References are stored in raw image space, so they are normalized once
  /// at load time into the same space as live frames.
  static List<double> _normalizeFrame(List<double> f) {
    if (f.length < 63) return f;
    final wx = f[0], wy = f[1], wz = f[2];
    final dx = f[36] - f[27]; // tip(12).x - mcp(9).x
    final dy = f[37] - f[28];
    final dz = f[38] - f[29];
    final midLen = sqrt(dx * dx + dy * dy + dz * dz);
    final scale = midLen < 0.001 ? 1.0 : midLen;
    final out = List<double>.filled(63, 0);
    for (var i = 0; i < 21; i++) {
      out[i * 3] = (f[i * 3] - wx) / scale;
      out[i * 3 + 1] = (f[i * 3 + 1] - wy) / scale;
      out[i * 3 + 2] = (f[i * 3 + 2] - wz) / scale;
    }
    return out;
  }

  /// Parses a stored flat landmark payload (multiples of 63 values) into one
  /// pre-normalized sequence. Returns null for malformed/empty payloads.
  static _RefSeq? _parseNormalized(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final nums = <double>[];
      for (final v in decoded) {
        if (v is! num) return null;
        nums.add(v.toDouble());
      }
      final frames = <List<double>>[];
      for (var i = 0; i + 62 < nums.length; i += 63) {
        frames.add(_normalizeFrame(nums.sublist(i, i + 63)));
      }
      return frames.isEmpty ? null : _RefSeq(frames);
    } catch (_) {
      return null;
    }
  }

  double _frameRms(List<double> a, List<double> b) {
    double sum = 0;
    for (var i = 0; i < 63; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sqrt(sum / 63);
  }

  double _frameDist(List<double> a, List<double> b) {
    double sum = 0;
    final len = a.length < b.length ? a.length : b.length;
    if (len == 0) return double.infinity;
    for (var i = 0; i < len; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sqrt(sum / len);
  }

  /// Full-matrix DTW with rolling rows — same result as the previous
  /// matrix version, but O(m) memory and no per-cell list allocations.
  double _dtwDistance(List<List<double>> a, List<List<double>> b) {
    final n = a.length;
    final m = b.length;
    if (n == 0 || m == 0) return double.infinity;

    var prev = List<double>.filled(m, 0);
    var cur = List<double>.filled(m, 0);

    prev[0] = _frameDist(a[0], b[0]);
    for (var j = 1; j < m; j++) {
      prev[j] = prev[j - 1] + _frameDist(a[0], b[j]);
    }

    for (var i = 1; i < n; i++) {
      cur[0] = prev[0] + _frameDist(a[i], b[0]);
      for (var j = 1; j < m; j++) {
        final diag = prev[j - 1];
        final up = prev[j];
        final left = cur[j - 1];
        final minPrev =
            diag < up ? (diag < left ? diag : left) : (up < left ? up : left);
        cur[j] = _frameDist(a[i], b[j]) + minPrev;
      }
      final tmp = prev;
      prev = cur;
      cur = tmp;
    }
    return prev[m - 1] / (n + m);
  }
}
