import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/translation_model.dart';
import '../models/translation_detail_model.dart';

class TranslationRepository {
  final DbHelper _db = DbHelper();

  Future<Database> get _dbConn => _db.database;

  Future<int> insertTranslation(TranslationModel translation) async {
    final db = await _dbConn;
    return db.insert('translations', translation.toMap()..remove('id'));
  }

  Future<TranslationModel?> getTranslationById(int id) async {
    final db = await _dbConn;
    final maps =
        await db.query('translations', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return TranslationModel.fromMap(maps.first);
  }

  Future<List<TranslationModel>> getAllTranslations() async {
    final db = await _dbConn;
    final maps =
        await db.query('translations', orderBy: 'created_at DESC');
    return maps.map((m) => TranslationModel.fromMap(m)).toList();
  }

  Future<List<TranslationModel>> getTranslationsByUser(int userId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'translations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => TranslationModel.fromMap(m)).toList();
  }

  Future<int> updateTranslation(TranslationModel translation) async {
    final db = await _dbConn;
    return db.update(
      'translations',
      translation.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [translation.id],
    );
  }

  Future<int> deleteTranslation(int id) async {
    final db = await _dbConn;
    await db.delete(
      'translation_details',
      where: 'translation_id = ?',
      whereArgs: [id],
    );
    return db.delete('translations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertDetail(TranslationDetailModel detail) async {
    final db = await _dbConn;
    return db.insert('translation_details', detail.toMap()..remove('id'));
  }

  Future<List<TranslationDetailModel>> getDetailsForTranslation(
      int translationId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'translation_details',
      where: 'translation_id = ?',
      whereArgs: [translationId],
      orderBy: 'sequence_order ASC',
    );
    return maps.map((m) => TranslationDetailModel.fromMap(m)).toList();
  }

  Future<int> deleteDetailsForTranslation(int translationId) async {
    final db = await _dbConn;
    return db.delete(
      'translation_details',
      where: 'translation_id = ?',
      whereArgs: [translationId],
    );
  }
}
