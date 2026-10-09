class EvaluationLogModel {
  final int? id;
  final int? translationId;
  final int? totalSigns;
  final int? recognizedSigns;
  final double? accuracyPercentage;
  final double? avgInferenceMs;
  final double? avgFps;
  final int? usabilityRating;
  final String? createdAt;

  EvaluationLogModel({
    this.id,
    this.translationId,
    this.totalSigns,
    this.recognizedSigns,
    this.accuracyPercentage,
    this.avgInferenceMs,
    this.avgFps,
    this.usabilityRating,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'translation_id': translationId,
        'total_signs': totalSigns,
        'recognized_signs': recognizedSigns,
        'accuracy_percentage': accuracyPercentage,
        'avg_inference_ms': avgInferenceMs,
        'avg_fps': avgFps,
        'usability_rating': usabilityRating,
        'created_at': createdAt,
      };

  factory EvaluationLogModel.fromMap(Map<String, dynamic> map) =>
      EvaluationLogModel(
        id: map['id'] as int?,
        translationId: map['translation_id'] as int?,
        totalSigns: map['total_signs'] as int?,
        recognizedSigns: map['recognized_signs'] as int?,
        accuracyPercentage: map['accuracy_percentage'] as double?,
        avgInferenceMs: map['avg_inference_ms'] as double?,
        avgFps: map['avg_fps'] as double?,
        usabilityRating: map['usability_rating'] as int?,
        createdAt: map['created_at'] as String?,
      );
}
