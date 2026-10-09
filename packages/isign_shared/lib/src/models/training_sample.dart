import 'dart:convert';

class TrainingSample {
  final int? id;
  final int signId;
  final List<double> landmarks;
  final String handedness;
  final int handIdx;
  final int synced;
  final DateTime? recordedAt;
  final String? userName;

  TrainingSample({
    this.id,
    required this.signId,
    required this.landmarks,
    this.handedness = 'unknown',
    this.handIdx = 0,
    this.synced = 0,
    this.recordedAt,
    this.userName,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sign_id': signId,
    'landmarks_json': jsonEncode(landmarks),
    'handedness': handedness,
    'hand_idx': handIdx,
    'synced': synced,
    if (recordedAt != null) 'recorded_at': recordedAt!.toIso8601String(),
    if (userName != null) 'user_name': userName,
  };

  factory TrainingSample.fromMap(Map<String, dynamic> map) => TrainingSample(
    id: map['id'] as int?,
    signId: map['sign_id'] as int,
    landmarks: (jsonDecode(map['landmarks_json'] as String) as List<dynamic>).cast<double>(),
    handedness: map['handedness'] as String? ?? 'unknown',
    handIdx: map['hand_idx'] as int? ?? 0,
    synced: map['synced'] as int? ?? 0,
    recordedAt: map['recorded_at'] != null
        ? DateTime.tryParse(map['recorded_at'] as String)
        : null,
    userName: map['user_name'] as String?,
  );
}
