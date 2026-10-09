class SignCatalogEntry {
  final int signId;
  final String signName;
  final String description;
  final int categoryId;
  final int version;
  final List<String> landmarkSamplePaths;
  final DateTime updatedAt;
  final String updatedBy;

  SignCatalogEntry({
    required this.signId,
    required this.signName,
    required this.description,
    required this.categoryId,
    required this.version,
    required this.landmarkSamplePaths,
    required this.updatedAt,
    required this.updatedBy,
  });

  Map<String, dynamic> toFirestore() => {
    'signId': signId,
    'signName': signName,
    'description': description,
    'categoryId': categoryId,
    'version': version,
    'landmarkSamplePaths': landmarkSamplePaths,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory SignCatalogEntry.fromFirestore(Map<String, dynamic> data) => SignCatalogEntry(
    signId: data['signId'] as int,
    signName: data['signName'] as String,
    description: data['description'] as String? ?? '',
    categoryId: data['categoryId'] as int? ?? 0,
    version: data['version'] as int? ?? 1,
    landmarkSamplePaths: (data['landmarkSamplePaths'] as List<dynamic>?)?.cast<String>() ?? [],
    updatedAt: DateTime.parse(data['updatedAt'] as String),
    updatedBy: data['updatedBy'] as String? ?? '',
  );
}