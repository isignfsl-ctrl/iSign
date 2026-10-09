class SignMediaModel {
  final int? id;
  final int signId;
  final String filePath;
  final String mediaType;
  final String? createdAt;

  SignMediaModel({
    this.id,
    required this.signId,
    required this.filePath,
    required this.mediaType,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sign_id': signId,
        'file_path': filePath,
        'media_type': mediaType,
        'created_at': createdAt,
      };

  factory SignMediaModel.fromMap(Map<String, dynamic> map) => SignMediaModel(
        id: map['id'] as int?,
        signId: map['sign_id'] as int,
        filePath: map['file_path'] as String,
        mediaType: map['media_type'] as String,
        createdAt: map['created_at'] as String?,
      );
}
