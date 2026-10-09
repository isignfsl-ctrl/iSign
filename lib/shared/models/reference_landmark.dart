import 'dart:convert';

class ReferenceLandmark {
  final int? id;
  final int signId;
  final List<double> landmarks;
  final String handedness;
  final int handIdx;
  final int frameCount;
  final String cloudPath;
  final DateTime? downloadedAt;

  ReferenceLandmark({
    this.id,
    required this.signId,
    required this.landmarks,
    this.handedness = 'unknown',
    this.handIdx = 0,
    required this.frameCount,
    required this.cloudPath,
    this.downloadedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sign_id': signId,
    'landmarks_json': jsonEncode(landmarks),
    'handedness': handedness,
    'hand_idx': handIdx,
    'frame_count': frameCount,
    'cloud_path': cloudPath,
    if (downloadedAt != null) 'downloaded_at': downloadedAt!.toIso8601String(),
  };

  factory ReferenceLandmark.fromMap(Map<String, dynamic> map) => ReferenceLandmark(
    id: map['id'] as int?,
    signId: map['sign_id'] as int,
    landmarks: (jsonDecode(map['landmarks_json'] as String) as List<dynamic>).cast<double>(),
    handedness: map['handedness'] as String? ?? 'unknown',
    handIdx: map['hand_idx'] as int? ?? 0,
    frameCount: map['frame_count'] as int? ?? 0,
    cloudPath: map['cloud_path'] as String? ?? '',
    downloadedAt: map['downloaded_at'] != null
        ? DateTime.tryParse(map['downloaded_at'] as String)
        : null,
  );

  List<List<double>> get frames {
    final frames = <List<double>>[];
    for (int i = 0; i < landmarks.length; i += 63) {
      if (i + 63 <= landmarks.length) {
        frames.add(landmarks.sublist(i, i + 63));
      }
    }
    return frames;
  }
}
