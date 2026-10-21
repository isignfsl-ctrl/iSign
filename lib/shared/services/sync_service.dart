import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isign_shared/isign_shared.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/db_helper.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  bool _isConnected = false;
  String _connectionType = 'unknown';
  StreamSubscription? _connectivitySub;

  bool get isSyncing => _isSyncing;
  bool get isConnected => _isConnected;
  String get connectionType => _connectionType;

  void startMonitoring() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _isConnected = results.any((r) => r != ConnectivityResult.none);
      final hasWifi = results.any((r) => r == ConnectivityResult.wifi);
      final hasMobile = results.any((r) => r == ConnectivityResult.mobile);
      _connectionType = hasWifi ? 'WiFi' : (hasMobile ? 'Mobile' : (_isConnected ? 'Other' : 'None'));
    });
    _connectivity.checkConnectivity().then((results) {
      _isConnected = results.any((r) => r != ConnectivityResult.none);
      final hasWifi = results.any((r) => r == ConnectivityResult.wifi);
      final hasMobile = results.any((r) => r == ConnectivityResult.mobile);
      _connectionType = hasWifi ? 'WiFi' : (hasMobile ? 'Mobile' : (_isConnected ? 'Other' : 'None'));
    });
  }

  void stopMonitoring() {
    _connectivitySub?.cancel();
  }

  Future<SyncResult> syncJson({
    required String deviceId,
    required int signId,
    required String handedness,
    required int handIdx,
    required List<double> landmarks,
    required int frameCount,
    required String uid,
  }) async {
    if (_isSyncing) return SyncResult(success: false, error: 'Already syncing');
    if (!_isConnected) return SyncResult(success: false, error: 'No internet connection');

    _isSyncing = true;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonStr = jsonEncode({
        'signId': signId,
        'handedness': handedness,
        'handIdx': handIdx,
        'landmarks': landmarks,
        'frameCount': frameCount,
      });

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${signId}_$timestamp.json');
      await file.writeAsString(jsonStr);

      final storagePath = 'recordings/$deviceId/${signId}_${handedness}_${timestamp}.json';
      await _storage.ref(storagePath).putFile(file);
      await file.delete();

      await _firestore.collection('recordings').add({
        'deviceId': deviceId,
        'signId': signId,
        'landmarksPath': storagePath,
        'handedness': handedness,
        'handIdx': handIdx,
        'frameCount': frameCount,
        'status': 'pending',
        'submittedAt': DateTime.now().toIso8601String(),
      });

      await _firestore.collection('devices').doc(deviceId).set({
        'lastSync': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      _isSyncing = false;
      return SyncResult(success: true, synced: 1);
    } catch (e) {
      _isSyncing = false;
      return SyncResult(success: false, error: e.toString());
    }
  }

  Future<List<RecordingMetadata>> getPendingRecordings({String? uid}) async {
    try {
      Query query = _firestore.collection('recordings').where('status', isEqualTo: 'pending');
      if (uid != null) {
        query = query.where('deviceId', isEqualTo: uid);
      }
      query = query.orderBy('submittedAt', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data is Map<String, dynamic>) {
              return RecordingMetadata.fromFirestore(data, doc.id);
            }
            return null;
          })
          .whereType<RecordingMetadata>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> approveRecording(String recordingId, {String? notes, String? reviewedBy}) async {
    await _firestore.collection('recordings').doc(recordingId).update({
      'status': 'approved',
      'reviewedAt': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    });
    _updateDeviceTrust(recordingId, true);
  }

  Future<void> rejectRecording(String recordingId, {String? notes, String? reviewedBy}) async {
    await _firestore.collection('recordings').doc(recordingId).update({
      'status': 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    });
    _updateDeviceTrust(recordingId, false);
  }

  Future<void> _updateDeviceTrust(String recordingId, bool approved) async {
    try {
      final doc = await _firestore.collection('recordings').doc(recordingId).get();
      final data = doc.data();
      if (data == null) return;
      final deviceId = data['deviceId'] as String?;
      if (deviceId == null) return;

      final field = approved ? 'trust_approvedCount' : 'trust_rejectedCount';
      await _firestore.collection('devices').doc(deviceId).update({
        field: FieldValue.increment(1),
        'lastReview': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<SyncResult> batchSyncTrainingSamples({
    required List<TrainingSample> samples,
    required String deviceId,
    required String uid,
    void Function(int progress, int total)? onProgress,
  }) async {
    if (_isSyncing) return SyncResult(success: false, error: 'Already syncing');

    // Re-check connectivity at call time — the cached flag can be stale if
    // startMonitoring() hasn't delivered its first event yet.
    final status = await _connectivity.checkConnectivity();
    _isConnected = status.any((r) => r != ConnectivityResult.none);
    if (!_isConnected) return SyncResult(success: false, error: 'No internet connection');

    _isSyncing = true;
    int synced = 0;
    final uploadedIds = <int>[];
    String? firstError;

    try {
      final db = await DbHelper().database;
      final groups = <String, List<TrainingSample>>{};
      for (final s in samples) {
        final key = '${s.signId}_${s.handedness}_${s.handIdx}';
        groups.putIfAbsent(key, () => []).add(s);
      }

      final total = groups.length;

      for (final entry in groups.entries) {
        final groupSamples = entry.value;
        if (groupSamples.isEmpty) continue;

        // Each group is independent: one bad group must not block the rest.
        try {
          final first = groupSamples.first;
          final allLandmarks = groupSamples.map((s) => s.landmarks).toList();
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // Look up sign name
          final signRows = await db.query('fsl_signs',
              columns: ['sign_name'],
              where: 'id = ?', whereArgs: [first.signId]);
          final signName = signRows.isNotEmpty
              ? (signRows.first['sign_name'] as String? ?? '')
              : '';

          // Compute quality scores
          final quality = _computeQuality(allLandmarks);

          // Frames are stored inline in the Firestore document — this project
          // has no Cloud Storage bucket (billing not enabled).
          final jsonStr = jsonEncode({
            'signId': first.signId,
            'handedness': first.handedness,
            'handIdx': first.handIdx,
            'frames': allLandmarks,
            'frameCount': allLandmarks.length,
            'quality': quality,
          });

          final storagePath = 'recordings/$deviceId/${entry.key}_$timestamp.json';

          await _firestore.collection('recordings').add({
            'deviceId': deviceId,
            'signId': first.signId,
            'signName': signName,
            'landmarksPath': storagePath,
            'framesJson': jsonStr,
            'handedness': first.handedness,
            'handIdx': first.handIdx,
            'frameCount': allLandmarks.length,
            'durationMs': groupSamples.length * 33,
            'status': 'pending',
            'submittedAt': DateTime.now().toIso8601String(),
            'quality_motionScore': quality['motionScore'],
            'quality_shapeConsistency': quality['shapeConsistency'],
          });

          synced++;
          uploadedIds.addAll(groupSamples.map((s) => s.id).whereType<int>());
        } catch (e) {
          firstError ??= e.toString();
        }
        onProgress?.call(synced, total);
      }

      await _firestore.collection('devices').doc(deviceId).set({
        'lastSync': DateTime.now().toIso8601String(),
        'totalUploads': FieldValue.increment(synced),
      }, SetOptions(merge: true));

      _isSyncing = false;
      if (firstError != null) {
        return SyncResult(
            success: false, error: firstError, synced: synced, sampleIds: uploadedIds);
      }
      return SyncResult(success: true, synced: synced, sampleIds: uploadedIds);
    } catch (e) {
      _isSyncing = false;
      return SyncResult(
          success: false, error: e.toString(), synced: synced, sampleIds: uploadedIds);
    }
  }

  Future<SyncResult> downloadApprovedRecordings({
    void Function(int progress, int total)? onProgress,
  }) async {
    if (_isSyncing) return SyncResult(success: false, error: 'Already syncing');
    if (!_isConnected) return SyncResult(success: false, error: 'No internet connection');

    _isSyncing = true;
    int downloaded = 0;

    try {
      final db = await DbHelper().database;

      // Get all approved recordings from cloud
      final snapshot = await _firestore
          .collection('recordings')
          .where('status', isEqualTo: 'approved')
          .get();

      final total = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final signId = data['signId'] as int?;
        final framesJson = data['framesJson'] as String?;

        if (signId == null || framesJson == null) continue;

        // Check if already downloaded
        final cloudPath = 'recordings/${doc.id}';
        final existing = await db.query('reference_landmarks',
            where: 'cloud_path = ?', whereArgs: [cloudPath]);
        if (existing.isNotEmpty) continue;

        try {
          final payload = jsonDecode(framesJson) as Map<String, dynamic>;
          final frames = payload['frames'] as List<dynamic>?;
          if (frames == null || frames.isEmpty) continue;

          final allLandmarks = <double>[];
          for (final frame in frames) {
            if (frame is List) {
              for (final v in frame) {
                allLandmarks.add((v as num).toDouble());
              }
            }
          }

          await db.insert('reference_landmarks', {
            'sign_id': signId,
            'landmarks_json': jsonEncode(allLandmarks),
            'handedness': data['handedness'] as String? ?? 'unknown',
            'hand_idx': data['handIdx'] as int? ?? 0,
            'frame_count': frames.length,
            'cloud_path': cloudPath,
          });

          // Update training status
          final refCount = await db.rawQuery(
            'SELECT COUNT(*) as cnt FROM reference_landmarks WHERE sign_id = ?',
            [signId],
          );
          final count = (refCount.first['cnt'] as int?) ?? 0;
          final newStatus = count >= 5 ? 'trained' : 'pending';
          await db.update('fsl_signs', {'training_status': newStatus},
              where: 'id = ?', whereArgs: [signId]);

          downloaded++;
        } catch (_) {
          // Skip individual failures
        }

        onProgress?.call(downloaded, total);
      }

      _isSyncing = false;
      return SyncResult(success: true, synced: downloaded);
    } catch (e) {
      _isSyncing = false;
      return SyncResult(success: false, error: e.toString(), synced: downloaded);
    }
  }

  Map<String, double> _computeQuality(List<List<double>> allLandmarks) {
    if (allLandmarks.length < 2) {
      return {'motionScore': 0.0, 'shapeConsistency': 1.0};
    }

    double totalMotion = 0.0;
    double totalShapeDiff = 0.0;
    int pairs = 0;

    for (int f = 0; f < allLandmarks.length - 1; f++) {
      final curr = allLandmarks[f];
      final next = allLandmarks[f + 1];
      if (curr.length < 63 || next.length < 63) continue;

      // Motion: wrist displacement (landmark 0, indices 0,1,2)
      final dx = curr[0] - next[0];
      final dy = curr[1] - next[1];
      final dz = curr[2] - next[2];
      totalMotion += (dx * dx + dy * dy + dz * dz);

      // Shape consistency: average landmark distance
      double sumDist = 0.0;
      for (int i = 0; i < 21; i++) {
        final ci = i * 3;
        final sd = (curr[ci] - next[ci]) * (curr[ci] - next[ci])
            + (curr[ci + 1] - next[ci + 1]) * (curr[ci + 1] - next[ci + 1])
            + (curr[ci + 2] - next[ci + 2]) * (curr[ci + 2] - next[ci + 2]);
        sumDist += sd;
      }
      totalShapeDiff += sumDist / 21;
      pairs++;
    }

    if (pairs == 0) return {'motionScore': 0.0, 'shapeConsistency': 1.0};

    final motionScore = (totalMotion / pairs).clamp(0.0, 1.0);
    final rawConsistency = (totalShapeDiff / pairs);
    final shapeConsistency = (1.0 - rawConsistency.clamp(0.0, 1.0));

    return {'motionScore': motionScore, 'shapeConsistency': shapeConsistency};
  }
}

class SyncResult {
  final bool success;
  final int synced;
  final String? error;
  final List<int> sampleIds;
  SyncResult({
    required this.success,
    this.synced = 0,
    this.error,
    this.sampleIds = const [],
  });
}