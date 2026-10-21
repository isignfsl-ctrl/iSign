import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'isign.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        language_preference TEXT DEFAULT 'Filipino',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        english_name TEXT
      )
    ''');
    // Seed categories table with default data matching admin panel mapping
    await db.execute('''
      INSERT INTO categories (id, category_name, english_name) VALUES
      (0, 'Alpabeto', 'Alphabet'),
      (1, 'Mga Karaniwang Parirala', 'Common Phrases'),
      (2, 'Mga Bilang', 'Numbers'),
      (3, 'Mga Pangunahing Galaw', 'Basic Gestures')
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
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        mode TEXT NOT NULL,
        output_language TEXT DEFAULT 'Filipino',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE translation_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        translation_id INTEGER NOT NULL,
        sign_id INTEGER,
        sequence_order INTEGER,
        translated_text TEXT,
        confidence_score REAL,
        FOREIGN KEY (translation_id) REFERENCES translations(id),
        FOREIGN KEY (sign_id) REFERENCES fsl_signs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE recordings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        file_path TEXT NOT NULL,
        duration INTEGER,
        transcript TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        sign_id INTEGER,
        comment TEXT,
        rating INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id),
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
    await db.execute('''
      CREATE TABLE evaluation_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        translation_id INTEGER,
        total_signs INTEGER,
        recognized_signs INTEGER,
        accuracy_percentage REAL,
        avg_inference_ms REAL,
        avg_fps REAL,
        usability_rating INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (translation_id) REFERENCES translations(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE training_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sign_id INTEGER NOT NULL,
        landmarks_json TEXT NOT NULL,
        recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        handedness TEXT DEFAULT 'unknown',
        hand_idx INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (sign_id) REFERENCES fsl_signs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE reference_landmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sign_id INTEGER NOT NULL,
        landmarks_json TEXT NOT NULL,
        handedness TEXT DEFAULT 'unknown',
        hand_idx INTEGER DEFAULT 0,
        frame_count INTEGER DEFAULT 0,
        cloud_path TEXT NOT NULL,
        downloaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sign_id) REFERENCES fsl_signs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS training_samples (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sign_id INTEGER NOT NULL,
          landmarks_json TEXT NOT NULL,
          recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (sign_id) REFERENCES fsl_signs(id)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE training_samples ADD COLUMN handedness TEXT DEFAULT 'unknown'
      ''');
      await db.execute('''
        ALTER TABLE training_samples ADD COLUMN hand_idx INTEGER DEFAULT 0
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE training_samples ADD COLUMN synced INTEGER DEFAULT 0
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE categories ADD COLUMN english_name TEXT
      ''');
      await db.execute('''
        ALTER TABLE fsl_signs ADD COLUMN english_name TEXT
      ''');
      await db.execute('''
        ALTER TABLE fsl_signs ADD COLUMN english_description TEXT
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        ALTER TABLE fsl_signs ADD COLUMN training_status TEXT DEFAULT 'untrained'
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reference_landmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sign_id INTEGER NOT NULL,
          landmarks_json TEXT NOT NULL,
          handedness TEXT DEFAULT 'unknown',
          hand_idx INTEGER DEFAULT 0,
          frame_count INTEGER DEFAULT 0,
          cloud_path TEXT NOT NULL,
          downloaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (sign_id) REFERENCES fsl_signs(id)
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        ALTER TABLE users ADD COLUMN user_name TEXT
      ''');
      await db.execute('''
        ALTER TABLE training_samples ADD COLUMN user_name TEXT
      ''');
      // Seed categories table with default data matching admin panel mapping
      await db.execute('''
        INSERT OR IGNORE INTO categories (id, category_name, english_name) VALUES
        (0, 'Alpabeto', 'Alphabet'),
        (1, 'Mga Karaniwang Parirala', 'Common Phrases'),
        (2, 'Mga Bilang', 'Numbers'),
        (3, 'Mga Pangunahing Galaw', 'Basic Gestures')
      ''');
    }
  }
}