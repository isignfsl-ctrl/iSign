class TranslationDetailModel {
  final int? id;
  final int translationId;
  final int? signId;
  final int? sequenceOrder;
  final String? translatedText;
  final double? confidenceScore;

  TranslationDetailModel({
    this.id,
    required this.translationId,
    this.signId,
    this.sequenceOrder,
    this.translatedText,
    this.confidenceScore,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'translation_id': translationId,
        'sign_id': signId,
        'sequence_order': sequenceOrder,
        'translated_text': translatedText,
        'confidence_score': confidenceScore,
      };

  factory TranslationDetailModel.fromMap(Map<String, dynamic> map) =>
      TranslationDetailModel(
        id: map['id'] as int?,
        translationId: map['translation_id'] as int,
        signId: map['sign_id'] as int?,
        sequenceOrder: map['sequence_order'] as int?,
        translatedText: map['translated_text'] as String?,
        confidenceScore: map['confidence_score'] as double?,
      );
}
