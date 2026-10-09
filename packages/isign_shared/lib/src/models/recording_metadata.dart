enum RecordingStatus { pending, approved, rejected }

class RecordingMetadata {
  final String recordingId;
  final String deviceId;
  final int signId;
  final String signName;
  final String handedness;
  final int handIdx;
  final int frameCount;
  final int durationMs;
  final String landmarksPath;
  final String? videoPath;
  final String? thumbnailPath;
  final RecordingStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? notes;
  final double? motionScore;
  final double? shapeConsistency;

  RecordingMetadata({
    required this.recordingId,
    required this.deviceId,
    required this.signId,
    required this.signName,
    required this.handedness,
    required this.handIdx,
    required this.frameCount,
    required this.durationMs,
    required this.landmarksPath,
    this.videoPath,
    this.thumbnailPath,
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
    'handedness': handedness,
    'handIdx': handIdx,
    'frameCount': frameCount,
    'durationMs': durationMs,
    'landmarksPath': landmarksPath,
    if (videoPath != null) 'videoPath': videoPath,
    if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
    'status': status.name,
    'submittedAt': submittedAt.toIso8601String(),
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
    if (notes != null) 'notes': notes,
    if (motionScore != null) 'quality_motionScore': motionScore,
    if (shapeConsistency != null) 'quality_shapeConsistency': shapeConsistency,
  };

  factory RecordingMetadata.fromFirestore(Map<String, dynamic> data, String id) => RecordingMetadata(
    recordingId: id,
    deviceId: data['deviceId'] as String,
    signId: data['signId'] as int,
    signName: data['signName'] as String,
    handedness: data['handedness'] as String? ?? 'unknown',
    handIdx: data['handIdx'] as int? ?? 0,
    frameCount: data['frameCount'] as int,
    durationMs: data['durationMs'] as int,
    landmarksPath: data['landmarksPath'] as String,
    videoPath: data['videoPath'] as String?,
    thumbnailPath: data['thumbnailPath'] as String?,
    status: RecordingStatus.values.firstWhere((s) => s.name == (data['status'] as String?), orElse: () => RecordingStatus.pending),
    submittedAt: DateTime.parse(data['submittedAt'] as String),
    reviewedAt: data['reviewedAt'] != null ? DateTime.parse(data['reviewedAt'] as String) : null,
    reviewedBy: data['reviewedBy'] as String?,
    notes: data['notes'] as String?,
    motionScore: (data['quality_motionScore'] as num?)?.toDouble(),
    shapeConsistency: (data['quality_shapeConsistency'] as num?)?.toDouble(),
  );
}
