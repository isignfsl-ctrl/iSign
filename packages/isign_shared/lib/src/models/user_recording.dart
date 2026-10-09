import 'package:cloud_firestore/cloud_firestore.dart';

import 'recording_metadata.dart';

class UserRecording {
  final String recordingId;
  final String deviceId;
  final int signId;
  final String signName;
  final String userName;
  final String userId;
  final String handedness;
  final int handIdx;
  final int frameCount;
  final int durationMs;
  final String landmarksUrl;
  final RecordingStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? notes;
  final double? motionScore;
  final double? shapeConsistency;

  UserRecording({
    required this.recordingId,
    required this.deviceId,
    required this.signId,
    required this.signName,
    required this.userName,
    required this.userId,
    required this.handedness,
    required this.handIdx,
    required this.frameCount,
    required this.durationMs,
    required this.landmarksUrl,
    this.status = RecordingStatus.pending,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.notes,
    this.motionScore,
    this.shapeConsistency,
  });

  Map<String, dynamic> toFirestore() => {
    'deviceId': deviceId,
    'signId': signId,
    'signName': signName,
    'userName': userName,
    'userId': userId,
    'handedness': handedness,
    'handIdx': handIdx,
    'frameCount': frameCount,
    'durationMs': durationMs,
    'landmarksUrl': landmarksUrl,
    'status': status.name,
    'submittedAt': submittedAt.toIso8601String(),
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
    if (notes != null) 'notes': notes,
    if (motionScore != null) 'motionScore': motionScore,
    if (shapeConsistency != null) 'shapeConsistency': shapeConsistency,
  };

  factory UserRecording.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return UserRecording(
      recordingId: id,
      deviceId: data['deviceId'] as String,
      signId: data['signId'] as int,
      signName: data['signName'] as String,
      userName: data['userName'] as String? ?? 'Unknown',
      userId: data['userId'] as String? ?? '',
      handedness: data['handedness'] as String? ?? 'unknown',
      handIdx: data['handIdx'] as int? ?? 0,
      frameCount: data['frameCount'] as int,
      durationMs: data['durationMs'] as int,
      landmarksUrl: data['landmarksUrl'] as String? ?? '',
      status: RecordingStatus.values.firstWhere((s) => s.name == (data['status'] as String?), orElse: () => RecordingStatus.pending),
      submittedAt: parseTimestamp(data['submittedAt']) ?? DateTime.now(),
      reviewedAt: parseTimestamp(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      notes: data['notes'] as String?,
      motionScore: (data['motionScore'] as num?)?.toDouble(),
      shapeConsistency: (data['shapeConsistency'] as num?)?.toDouble(),
    );
  }
}