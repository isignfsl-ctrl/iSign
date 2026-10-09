import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import '../models/fsl_sign_model.dart';
import '../../shared/models/reference_landmark.dart';
import '../../shared/services/training_upload_service.dart';
import 'package:isign_shared/isign_shared.dart';

class TrainingRepository {
  static const int minSamplesForTrained = 5;

  Future<int> getSampleCount(int signId) async {
    final db = await DbHelper().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM training_samples WHERE sign_id = ?',
      [signId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> getTotalCount() async {
    final db = await DbHelper().database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM training_samples');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getSamplesBySign(int signId) async {
    final db = await DbHelper().database;
    return await db.query('training_samples',
        where: 'sign_id = ?', whereArgs: [signId]);
  }

  Future<void> insertSample(TrainingSample sample) async {
    final db = await DbHelper().database;
    await db.insert('training_samples', sample.toMap());
    
    // Trigger background upload
    TrainingUploadService().scheduleUpload();
  }

  Future<String> exportAsCsv({bool temporal = false}) async {
    final db = await DbHelper().database;
    final rows = await db.query('training_samples',
        orderBy: 'sign_id, recorded_at');
    if (rows.isEmpty) return '';

    final buf = StringBuffer('sign_id,handedness,hand_idx,');
    if (temporal) {
      buf.writeln('frame,x,y,z');
      for (final row in rows) {
        final signId = row['sign_id'];
        final handedness = row['handedness'] ?? 'unknown';
        final handIdx = row['hand_idx'] ?? 0;
        final landmarksJson = row['landmarks_json'] as String;
        final landmarks = jsonDecode(landmarksJson) as List<dynamic>;
        final frameCount = landmarks.length ~/ 63;
        for (int f = 0; f < frameCount; f++) {
          for (int j = 0; j < 21; j++) {
            final idx = f * 63 + j * 3;
            final x = idx < landmarks.length ? (landmarks[idx] as num).toDouble() : 0;
            final y = idx + 1 < landmarks.length ? (landmarks[idx + 1] as num).toDouble() : 0;
            final z = idx + 2 < landmarks.length ? (landmarks[idx + 2] as num).toDouble() : 0;
            buf.writeln('$signId,$handedness,$handIdx,$f,$x,$y,$z');
          }
        }
      }
    } else {
      buf.writeln('landmark_index,x,y,z');
      for (final row in rows) {
        final signId = row['sign_id'];
        final handedness = row['handedness'] ?? 'unknown';
        final handIdx = row['hand_idx'] ?? 0;
        final landmarksJson = row['landmarks_json'] as String;
        final landmarks = jsonDecode(landmarksJson) as List<dynamic>;
        for (int i = 0; i < landmarks.length; i += 3) {
          final x = i < landmarks.length ? (landmarks[i] as num).toDouble() : 0;
          final y = i + 1 < landmarks.length ? (landmarks[i + 1] as num).toDouble() : 0;
          final z = i + 2 < landmarks.length ? (landmarks[i + 2] as num).toDouble() : 0;
          buf.writeln('$signId,$handedness,$handIdx,${i ~/ 3},$x,$y,$z');
        }
      }
    }
    return buf.toString();
  }

  Future<int> getReferenceCount(int signId) async {
    final db = await DbHelper().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM reference_landmarks WHERE sign_id = ?',
      [signId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<List<ReferenceLandmark>> getReferences(int signId) async {
    final db = await DbHelper().database;
    final rows = await db.query('reference_landmarks',
        where: 'sign_id = ?', whereArgs: [signId]);
    return rows.map((r) => ReferenceLandmark.fromMap(r)).toList();
  }

  Future<List<ReferenceLandmark>> getAllReferences() async {
    final db = await DbHelper().database;
    final rows = await db.query('reference_landmarks');
    return rows.map((r) => ReferenceLandmark.fromMap(r)).toList();
  }

  Future<void> clearReferences(int signId) async {
    final db = await DbHelper().database;
    await db.delete('reference_landmarks',
        where: 'sign_id = ?', whereArgs: [signId]);
  }

  Future<void> insertReference(ReferenceLandmark ref) async {
    final db = await DbHelper().database;
    await db.insert('reference_landmarks', ref.toMap());
  }

  Future<String> getTrainingStatus(int signId) async {
    final db = await DbHelper().database;
    final rows = await db.query('fsl_signs',
        columns: ['training_status'],
        where: 'id = ?', whereArgs: [signId]);
    if (rows.isEmpty) return 'untrained';
    return rows.first['training_status'] as String? ?? 'untrained';
  }

  Future<void> updateTrainingStatus(int signId, String status) async {
    final db = await DbHelper().database;
    await db.update('fsl_signs', {'training_status': status},
        where: 'id = ?', whereArgs: [signId]);
  }

  Future<void> refreshTrainingStatus(int signId) async {
    final refCount = await getReferenceCount(signId);
    final newStatus = refCount >= minSamplesForTrained ? 'trained' : 'untrained';
    await updateTrainingStatus(signId, newStatus);
  }

  Future<void> refreshAllTrainingStatus() async {
    final db = await DbHelper().database;
    final signs = await db.query('fsl_signs');
    for (final sign in signs) {
      final signId = sign['id'] as int;
      final refCount = await getReferenceCount(signId);
      final newStatus = refCount >= minSamplesForTrained ? 'trained' : 'untrained';
      final currentStatus = sign['training_status'] as String? ?? 'untrained';
      if (currentStatus != newStatus) {
        await db.update('fsl_signs', {'training_status': newStatus},
            where: 'id = ?', whereArgs: [signId]);
      }
    }
  }

  Future<int> downloadAndStoreReference(
    String cloudPath,
    int signId,
  ) async {
    try {
      final storage = FirebaseStorage.instance;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ref_${signId}_${DateTime.now().millisecondsSinceEpoch}.json');
      await storage.ref(cloudPath).writeToFile(file);
      final jsonStr = await file.readAsString();
      await file.delete();

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final frames = data['frames'] as List<dynamic>?;
      if (frames == null || frames.isEmpty) return 0;

      final allLandmarks = <double>[];
      for (final frame in frames) {
        if (frame is List) {
          for (final v in frame) {
            allLandmarks.add((v as num).toDouble());
          }
        }
      }

      final ref = ReferenceLandmark(
        signId: signId,
        landmarks: allLandmarks,
        handedness: data['handedness'] as String? ?? 'unknown',
        handIdx: data['handIdx'] as int? ?? 0,
        frameCount: frames.length,
        cloudPath: cloudPath,
        downloadedAt: DateTime.now(),
      );

      await insertReference(ref);
      return frames.length;
    } catch (_) {
      return 0;
    }
  }
}