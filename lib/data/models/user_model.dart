class UserModel {
  final int? id;
  final String name;
  final String role;
  final String languagePreference;
  final String? createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.role,
    this.languagePreference = 'Filipino',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'language_preference': languagePreference,
        'created_at': createdAt,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        role: map['role'] as String,
        languagePreference: map['language_preference'] as String? ?? 'Filipino',
        createdAt: map['created_at'] as String?,
      );
}
