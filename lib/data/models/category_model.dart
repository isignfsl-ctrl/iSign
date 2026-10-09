class CategoryModel {
  final int? id;
  final String categoryName;
  final String? categoryNameEn;

  CategoryModel({this.id, required this.categoryName, this.categoryNameEn});

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_name': categoryName,
        'english_name': categoryNameEn,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int?,
        categoryName: map['category_name'] as String,
        categoryNameEn: map['english_name'] as String?,
      );
}
