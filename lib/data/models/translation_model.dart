class TranslationModel {
  final int? id;
  final int? userId;
  final String mode;
  final String outputLanguage;
  final String? createdAt;

  TranslationModel({
    this.id,
    this.userId,
    required this.mode,
    this.outputLanguage = 'Filipino',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'mode': mode,
      'output_language': outputLanguage,
    };
    if (createdAt != null) map['created_at'] = createdAt;
    return map;
  }

  factory TranslationModel.fromMap(Map<String, dynamic> map) =>
      TranslationModel(
        id: map['id'] as int?,
        userId: map['user_id'] as int?,
        mode: map['mode'] as String,
        outputLanguage: map['output_language'] as String? ?? 'Filipino',
        createdAt: map['created_at'] as String?,
      );
}
