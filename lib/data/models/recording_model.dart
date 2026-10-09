class RecordingModel {
  final int? id;
  final int? userId;
  final String filePath;
  final int? duration;
  final String? transcript;
  final String? createdAt;

  RecordingModel({
    this.id,
    this.userId,
    required this.filePath,
    this.duration,
    this.transcript,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'file_path': filePath,
        'duration': duration,
        'transcript': transcript,
        'created_at': createdAt,
      };

  factory RecordingModel.fromMap(Map<String, dynamic> map) => RecordingModel(
        id: map['id'] as int?,
        userId: map['user_id'] as int?,
        filePath: map['file_path'] as String,
        duration: map['duration'] as int?,
        transcript: map['transcript'] as String?,
        createdAt: map['created_at'] as String?,
      );
}
