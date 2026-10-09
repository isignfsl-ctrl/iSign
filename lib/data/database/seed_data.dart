import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

class SeedData {
  static const _seedKey = 'seed_v3';

  Future<void> seedIfNeeded(Database db) async {
    final alreadySeeded = await _isAlreadySeeded(db);
    if (alreadySeeded) return;

    await db.execute('DROP TABLE IF EXISTS sign_media');
    await db.execute('DROP TABLE IF EXISTS fsl_signs');
    await db.execute('DROP TABLE IF EXISTS categories');
    await db.execute('DROP TABLE IF EXISTS model_versions');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        english_name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE fsl_signs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sign_name TEXT NOT NULL,
        english_name TEXT,
        description TEXT,
        english_description TEXT,
        category_id INTEGER,
        training_status TEXT DEFAULT 'untrained',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE sign_media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sign_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        media_type TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sign_id) REFERENCES fsl_signs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE model_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version_name TEXT NOT NULL,
        accuracy_score REAL,
        deployed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    final jsonString =
        await rootBundle.loadString('assets/seed/fsl_dictionary.json');
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final categories = data['categories'] as List<dynamic>?;

    if (categories == null) return;

    final batch = db.batch();

    for (final cat in categories) {
      final catName = cat['category_name'] as String;
      final catNameEn = cat['category_name_en'] as String?;
      final catId = await db.insert('categories', {
        'category_name': catName,
        'english_name': catNameEn,
      });

      final signs = cat['signs'] as List<dynamic>?;
      if (signs == null) continue;

      for (final sign in signs) {
        batch.insert('fsl_signs', {
          'sign_name': sign['sign_name'] as String,
          'english_name': sign['sign_name_en'] as String?,
          'description': sign['description'] as String?,
          'english_description': sign['description_en'] as String?,
          'category_id': catId,
        });
      }
    }

    await batch.commit(noResult: true);
    await _markSeeded(db);
  }

  Future<bool> _isAlreadySeeded(Database db) async {
    final result = await db.query(
      'model_versions',
      where: 'version_name = ?',
      whereArgs: [_seedKey],
    );
    return result.isNotEmpty;
  }

  Future<void> _markSeeded(Database db) async {
    await db.insert('model_versions', {
      'version_name': _seedKey,
      'accuracy_score': null,
    });
  }
}
