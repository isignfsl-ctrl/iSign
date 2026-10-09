import 'dart:convert';

class TrainingSample {
  final int? id;
  final int signId;
  final List<double> landmarks;
  final String handedness;
  final int handIdx;
  final DateTime? recordedAt;

  TrainingSample({
    this.id,
    required this.signId,
    required this.landmarks,
    this.handedness = 'unknown',
    this.handIdx = 0,
    this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sign_id': signId,
    'landmarks_json': jsonEncode(landmarks),
    'handedness': handedness,
    'hand_idx': handIdx,
    if (recordedAt != null) 'recorded_at': recordedAt!.toIso8601String(),
  };

  factory TrainingSample.fromMap(Map<String, dynamic> map) => TrainingSample(
    id: map['id'] as int?,
    signId: map['sign_id'] as int,
    landmarks: (jsonDecode(map['landmarks_json'] as String) as List<dynamic>).cast<double>(),
    handedness: map['handedness'] as String? ?? 'unknown',
    handIdx: map['hand_idx'] as int? ?? 0,
    recordedAt: map['recorded_at'] != null
        ? DateTime.tryParse(map['recorded_at'] as String)
        : null,
  );
}