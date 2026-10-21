import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/db_helper.dart';
import 'package:isign_shared/isign_shared.dart';

class TrainingUploadService {
  static const String _workName = 'trainingUploadTask';
  static const int _batchSize = 10;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize WorkManager for background sync
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Register periodic task for background sync (every 30 minutes)
    await Workmanager().registerPeriodicTask(
      'trainingUploadTask',
      'trainingUploadTask',
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
    );
  }

  /// WorkManager callback dispatcher (must be top-level or static)
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      final service = TrainingUploadService();
      await service._processPendingUploads();
      return true;
    });
  }

  /// Get pending unsynced samples count
  Future<int> getPendingCount() async {
    final db = await DbHelper().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM training_samples WHERE synced = 0',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Get unsynced samples in batches
  Future<List<TrainingSample>> getUnsyncedSamples({int limit = 10}) async {
    final db = await DbHelper().database;
    final maps = await db.query(
      'training_samples',
      where: 'synced = ?',
      whereArgs: [0],
      limit: limit,
      orderBy: 'recorded_at ASC',
    );

    return maps.map((map) => TrainingSample.fromMap(map)).toList();
  }

  /// Mark samples as synced
  Future<void> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await DbHelper().database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'training_samples',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Upload landmarks and create Firestore document
  Future<bool> _uploadSample(TrainingSample sample) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Frames are stored inline in the Firestore document — this project
      // has no Cloud Storage bucket (billing not enabled).
      final payload = jsonEncode({
        'signId': sample.signId,
        'handedness': sample.handedness,
        'handIdx': sample.handIdx,
        'frames': [sample.landmarks],
        'frameCount': 1,
        'quality': {'motionScore': 0.0, 'shapeConsistency': 1.0},
      });
      final logicalPath =
          'recordings/${user.uid}/${sample.signId}_${sample.recordedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}.json';

      // Create Firestore document (unified 'recordings' collection)
      await _firestore.collection('recordings').add({
        'deviceId': user.uid,
        'signId': sample.signId,
        'signName': sample.userName ?? 'Unknown',
        'landmarksPath': logicalPath,
        'framesJson': payload,
        'handedness': sample.handedness,
        'handIdx': sample.handIdx,
        'frameCount': 1,
        'durationMs': (sample.recordedAt != null
            ? DateTime.now().difference(sample.recordedAt!).inMilliseconds
            : 0),
        'status': 'pending',
        'submittedAt': sample.recordedAt?.toIso8601String()
            ?? DateTime.now().toIso8601String(),
        'quality_motionScore': 0.0,
        'quality_shapeConsistency': 1.0,
      });

      return true;
    } catch (e) {
      print('Upload failed: $e');
      return false;
    }
  }

  /// Mark samples as synced by signId + recordedAt
  Future<void> markSamplesSynced(List<TrainingSample> samples) async {
    if (samples.isEmpty) return;
    final db = await DbHelper().database;
    final batch = db.batch();
    for (final sample in samples) {
      final maps = await db.query(
        'training_samples',
        where: 'sign_id = ? AND recorded_at = ?',
        whereArgs: [
          sample.signId,
          sample.recordedAt?.toIso8601String() ?? '',
        ],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        batch.update(
          'training_samples',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [maps.first['id'] as int],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Process pending uploads in batches
  Future<void> _processPendingUploads() async {
    final successfulSamples = <TrainingSample>[];

    while (true) {
      final samples = await getUnsyncedSamples(limit: 10);
      if (samples.isEmpty) break;

      for (final sample in samples) {
        bool success = false;
        int retries = 0;

        while (retries < 3 && !success) {
          success = await _uploadSample(sample);
          if (!success) {
            retries++;
            await Future.delayed(Duration(seconds: 2 * retries));
          }
        }

        if (success) {
          successfulSamples.add(sample);
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Mark successfully uploaded samples as synced
    await markSamplesSynced(successfulSamples);

    // Update last sync timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
    await prefs.setInt('pending_sync_count', await getPendingCount());

    print('Sync complete: ${successfulSamples.length} uploaded');
  }

  /// Manually trigger sync (called after recording)
  Future<void> scheduleUpload() async {
    try {
      await Workmanager().registerOneOffTask(
        'trainingUploadTask',
        'trainingUploadTask',
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (_) {
      // WorkManager not initialized (e.g. synchronous failure) — the manual
      // Settings sync and the periodic task will pick the samples up instead.
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('last_sync_timestamp');
    if (str != null) return DateTime.tryParse(str);
    return null;
  }
}

/// WorkManager callback (must be top-level)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final service = TrainingUploadService();
    await service._processPendingUploads();
    return true;
  });
}