class FeedbackModel {
  final int? id;
  final int? userId;
  final int? signId;
  final String? comment;
  final int? rating;
  final String? createdAt;

  FeedbackModel({
    this.id,
    this.userId,
    this.signId,
    this.comment,
    this.rating,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'sign_id': signId,
        'comment': comment,
        'rating': rating,
        'created_at': createdAt,
      };

  factory FeedbackModel.fromMap(Map<String, dynamic> map) => FeedbackModel(
        id: map['id'] as int?,
        userId: map['user_id'] as int?,
        signId: map['sign_id'] as int?,
        comment: map['comment'] as String?,
        rating: map['rating'] as int?,
        createdAt: map['created_at'] as String?,
      );
}
