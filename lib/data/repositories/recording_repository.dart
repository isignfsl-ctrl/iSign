import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/recording_model.dart';

class RecordingRepository {
  final DbHelper _db = DbHelper();

  Future<Database> get _dbConn => _db.database;

  Future<int> insertRecording(RecordingModel recording) async {
    final db = await _dbConn;
    return db.insert('recordings', recording.toMap()..remove('id'));
  }

  Future<RecordingModel?> getRecordingById(int id) async {
    final db = await _dbConn;
    final maps =
        await db.query('recordings', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return RecordingModel.fromMap(maps.first);
  }

  Future<List<RecordingModel>> getAllRecordings() async {
    final db = await _dbConn;
    final maps = await db.query('recordings', orderBy: 'created_at DESC');
    return maps.map((m) => RecordingModel.fromMap(m)).toList();
  }

  Future<List<RecordingModel>> getRecordingsByUser(int userId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'recordings',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => RecordingModel.fromMap(m)).toList();
  }

  Future<int> updateRecording(RecordingModel recording) async {
    final db = await _dbConn;
    return db.update(
      'recordings',
      recording.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [recording.id],
    );
  }

  Future<int> deleteRecording(int id) async {
    final db = await _dbConn;
    return db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }
}
