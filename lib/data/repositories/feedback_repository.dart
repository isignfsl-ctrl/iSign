import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  final DbHelper _db = DbHelper();

  Future<Database> get _dbConn => _db.database;

  Future<int> insertFeedback(FeedbackModel feedback) async {
    final db = await _dbConn;
    return db.insert('feedback', feedback.toMap()..remove('id'));
  }

  Future<FeedbackModel?> getFeedbackById(int id) async {
    final db = await _dbConn;
    final maps =
        await db.query('feedback', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return FeedbackModel.fromMap(maps.first);
  }

  Future<List<FeedbackModel>> getAllFeedback() async {
    final db = await _dbConn;
    final maps = await db.query('feedback', orderBy: 'created_at DESC');
    return maps.map((m) => FeedbackModel.fromMap(m)).toList();
  }

  Future<List<FeedbackModel>> getFeedbackByUser(int userId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'feedback',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => FeedbackModel.fromMap(m)).toList();
  }

  Future<List<FeedbackModel>> getFeedbackBySign(int signId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'feedback',
      where: 'sign_id = ?',
      whereArgs: [signId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => FeedbackModel.fromMap(m)).toList();
  }

  Future<double?> getAverageRatingForSign(int signId) async {
    final db = await _dbConn;
    final result = await db.rawQuery(
      'SELECT AVG(rating) as avg_rating FROM feedback WHERE sign_id = ?',
      [signId],
    );
    return result.first['avg_rating'] as double?;
  }

  Future<int> deleteFeedback(int id) async {
    final db = await _dbConn;
    return db.delete('feedback', where: 'id = ?', whereArgs: [id]);
  }
}
