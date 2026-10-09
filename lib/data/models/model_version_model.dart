class ModelVersionModel {
  final int? id;
  final String versionName;
  final double? accuracyScore;
  final String? deployedAt;

  ModelVersionModel({
    this.id,
    required this.versionName,
    this.accuracyScore,
    this.deployedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'version_name': versionName,
        'accuracy_score': accuracyScore,
        'deployed_at': deployedAt,
      };

  factory ModelVersionModel.fromMap(Map<String, dynamic> map) =>
      ModelVersionModel(
        id: map['id'] as int?,
        versionName: map['version_name'] as String,
        accuracyScore: map['accuracy_score'] as double?,
        deployedAt: map['deployed_at'] as String?,
      );
}
