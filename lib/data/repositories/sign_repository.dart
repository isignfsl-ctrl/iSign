import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/category_model.dart';
import '../models/fsl_sign_model.dart';
import '../models/sign_media_model.dart';

class SignRepository {
  final DbHelper _db = DbHelper();

  Future<Database> get _dbConn => _db.database;

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await _dbConn;
    final maps = await db.query('categories', orderBy: 'category_name ASC');
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final db = await _dbConn;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await _dbConn;
    return db.insert('categories', category.toMap()..remove('id'));
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await _dbConn;
    return db.update(
      'categories',
      category.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _dbConn;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FslSignModel>> getAllSigns() async {
    final db = await _dbConn;
    final maps = await db.query('fsl_signs', orderBy: 'sign_name ASC');
    return maps.map((m) => FslSignModel.fromMap(m)).toList();
  }

  Future<List<FslSignModel>> getSignsByCategory(int categoryId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'fsl_signs',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'sign_name ASC',
    );
    return maps.map((m) => FslSignModel.fromMap(m)).toList();
  }

  Future<FslSignModel?> getSignById(int id) async {
    final db = await _dbConn;
    final maps = await db.query('fsl_signs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return FslSignModel.fromMap(maps.first);
  }

  Future<List<FslSignModel>> searchSigns(String query) async {
    final db = await _dbConn;
    final maps = await db.query(
      'fsl_signs',
      where: 'sign_name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'sign_name ASC',
    );
    return maps.map((m) => FslSignModel.fromMap(m)).toList();
  }

  Future<int> insertSign(FslSignModel sign) async {
    final db = await _dbConn;
    return db.insert('fsl_signs', sign.toMap()..remove('id'));
  }

  Future<int> updateSign(FslSignModel sign) async {
    final db = await _dbConn;
    return db.update(
      'fsl_signs',
      sign.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [sign.id],
    );
  }

  Future<int> deleteSign(int id) async {
    final db = await _dbConn;
    return db.delete('fsl_signs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SignMediaModel>> getMediaForSign(int signId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'sign_media',
      where: 'sign_id = ?',
      whereArgs: [signId],
    );
    return maps.map((m) => SignMediaModel.fromMap(m)).toList();
  }

  Future<int> insertMedia(SignMediaModel media) async {
    final db = await _dbConn;
    return db.insert('sign_media', media.toMap()..remove('id'));
  }

  Future<int> deleteMedia(int id) async {
    final db = await _dbConn;
    return db.delete('sign_media', where: 'id = ?', whereArgs: [id]);
  }
}
