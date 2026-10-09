import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/evaluation_log_model.dart';
import '../models/model_version_model.dart';

class EvaluationRepository {
  final DbHelper _db = DbHelper();

  Future<Database> get _dbConn => _db.database;

  Future<int> insertEvaluationLog(EvaluationLogModel log) async {
    final db = await _dbConn;
    return db.insert('evaluation_logs', log.toMap()..remove('id'));
  }

  Future<EvaluationLogModel?> getEvaluationLogById(int id) async {
    final db = await _dbConn;
    final maps =
        await db.query('evaluation_logs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return EvaluationLogModel.fromMap(maps.first);
  }

  Future<List<EvaluationLogModel>> getAllEvaluationLogs() async {
    final db = await _dbConn;
    final maps =
        await db.query('evaluation_logs', orderBy: 'created_at DESC');
    return maps.map((m) => EvaluationLogModel.fromMap(m)).toList();
  }

  Future<List<EvaluationLogModel>> getLogsByTranslation(int translationId) async {
    final db = await _dbConn;
    final maps = await db.query(
      'evaluation_logs',
      where: 'translation_id = ?',
      whereArgs: [translationId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => EvaluationLogModel.fromMap(m)).toList();
  }

  Future<double?> getAverageAccuracy() async {
    final db = await _dbConn;
    final result = await db.rawQuery(
      'SELECT AVG(accuracy_percentage) as avg_acc FROM evaluation_logs',
    );
    return result.first['avg_acc'] as double?;
  }

  Future<double?> getAverageInferenceMs() async {
    final db = await _dbConn;
    final result = await db.rawQuery(
      'SELECT AVG(avg_inference_ms) as avg_ms FROM evaluation_logs',
    );
    return result.first['avg_ms'] as double?;
  }

  Future<int> deleteEvaluationLog(int id) async {
    final db = await _dbConn;
    return db.delete('evaluation_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertModelVersion(ModelVersionModel version) async {
    final db = await _dbConn;
    return db.insert('model_versions', version.toMap()..remove('id'));
  }

  Future<ModelVersionModel?> getLatestModelVersion() async {
    final db = await _dbConn;
    final maps = await db.query(
      'model_versions',
      orderBy: 'deployed_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ModelVersionModel.fromMap(maps.first);
  }
}
