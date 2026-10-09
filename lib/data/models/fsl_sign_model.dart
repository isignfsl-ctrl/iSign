class FslSignModel {
  final int? id;
  final String signName;
  final String? signNameEn;
  final String? description;
  final String? descriptionEn;
  final int? categoryId;
  final String? createdAt;
  final String trainingStatus;

  FslSignModel({
    this.id,
    required this.signName,
    this.signNameEn,
    this.description,
    this.descriptionEn,
    this.categoryId,
    this.createdAt,
    this.trainingStatus = 'untrained',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sign_name': signName,
        'english_name': signNameEn,
        'description': description,
        'english_description': descriptionEn,
        'category_id': categoryId,
        'training_status': trainingStatus,
        'created_at': createdAt,
      };

  factory FslSignModel.fromMap(Map<String, dynamic> map) => FslSignModel(
        id: map['id'] as int?,
        signName: map['sign_name'] as String,
        signNameEn: map['english_name'] as String?,
        description: map['description'] as String?,
        descriptionEn: map['english_description'] as String?,
        categoryId: map['category_id'] as int?,
        trainingStatus: map['training_status'] as String? ?? 'untrained',
        createdAt: map['created_at'] as String?,
      );
}
