import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

class SeedData {
  static const _seedKey = 'seed_v3';
  static const _catRepairKey = 'cat_repair_v1';

  /// Canonical category ids — must match the admin panel mapping
  /// (0=Alphabet, 1=Common Phrases, 2=Numbers, 3=Basic Gestures).
  static const List<List<String>> canonicalCategories = [
    ['Alpabeto', 'Alphabet'],
    ['Mga Karaniwang Parirala', 'Common Phrases'],
    ['Mga Bilang', 'Numbers'],
    ['Mga Pangunahing Galaw', 'Basic Gestures'],
  ];

  static String canonicalName(int id) =>
      id >= 0 && id < canonicalCategories.length ? canonicalCategories[id][0] : 'Category $id';

  static int? nameToCanonicalId(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (var i = 0; i < canonicalCategories.length; i++) {
      if (canonicalCategories[i][0].toLowerCase() == n ||
          canonicalCategories[i][1].toLowerCase() == n) {
        return i;
      }
    }
    return null;
  }

  /// One-time, non-destructive repair: restores canonical category rows and
  /// rewrites bad category references using the bundled sign dictionary.
  /// Sign rows, training status and recordings are preserved.
  Future<void> repairCategories(Database db) async {
    try {
      final marker = await db.query('model_versions',
          where: 'version_name = ?', whereArgs: [_catRepairKey]);
      if (marker.isNotEmpty) return;

      // 1. Ensure canonical category rows exist.
      for (var i = 0; i < canonicalCategories.length; i++) {
        await db.execute(
            'INSERT OR IGNORE INTO categories (id, category_name, english_name) VALUES (?, ?, ?)',
            [i, canonicalCategories[i][0], canonicalCategories[i][1]]);
      }

      // 2. sign_name -> canonical category id from the bundled dictionary.
      final jsonString =
          await rootBundle.loadString('assets/seed/fsl_dictionary.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final cats = data['categories'] as List<dynamic>? ?? [];
      final nameToCat = <String, int>{};
      for (var i = 0; i < cats.length; i++) {
        final signs = cats[i]['signs'] as List<dynamic>? ?? [];
        for (final s in signs) {
          nameToCat[(s['sign_name'] as String)] = i;
        }
      }

      // 3. Rewrite bad references (e.g. legacy autoincrement ids like 4/20).
      final signs =
          await db.query('fsl_signs', columns: ['id', 'sign_name', 'category_id']);
      for (final s in signs) {
        final cur = s['category_id'] as int? ?? -1;
        final mapped = nameToCat[s['sign_name'] as String];
        int target;
        if (cur >= 0 && cur < canonicalCategories.length) {
          target = cur; // already canonical — trust it
        } else if (mapped != null) {
          target = mapped;
        } else {
          target = 0; // unknown sign — Alphabet (admin default)
        }
        if (target != cur) {
          await db.update('fsl_signs', {'category_id': target},
              where: 'id = ?', whereArgs: [s['id']]);
        }
      }

      // 4. Remove stray rows that duplicate a canonical category name.
      for (var i = 0; i < canonicalCategories.length; i++) {
        await db.delete('categories',
            where: 'id != ? AND (category_name = ? OR category_name = ?)',
            whereArgs: [i, canonicalCategories[i][0], canonicalCategories[i][1]]);
      }

      await db.insert('model_versions', {
        'version_name': _catRepairKey,
        'accuracy_score': null,
      });
    } catch (_) {
      // Repair is best-effort — sync will normalize categories as well.
    }
  }

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

    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final catName = cat['category_name'] as String;
      final catNameEn = cat['category_name_en'] as String?;
      // Seed with the canonical id (dictionary order == admin mapping 0..3).
      await db.insert('categories', {
        'id': i,
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
          'category_id': i,
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
