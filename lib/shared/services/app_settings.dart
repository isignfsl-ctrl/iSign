import 'package:flutter/material.dart';
import '../../data/database/db_helper.dart';

class AppSettings {
  AppSettings._();

  static final AppSettings _instance = AppSettings._();
  factory AppSettings() => _instance;

  static const _kThemeMode = 'settings_theme_mode';
  static const _kTextSize = 'settings_text_size';
  static const _kTtsSpeed = 'settings_tts_speed';
  static const _kLanguage = 'settings_language';
  static const _kColorScheme = 'settings_color_scheme';
  static const _kShowHistory = 'settings_show_history';
  static const _kCameraPref = 'settings_camera_pref';
  static const _kUserName = 'settings_user_name';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final ValueNotifier<double> textScale = ValueNotifier(1.0);
  final ValueNotifier<double> ttsSpeed = ValueNotifier(0.5);
  final ValueNotifier<String> language = ValueNotifier('Filipino');
  final ValueNotifier<String> colorSchemeId = ValueNotifier('indigo_depth');
  final ValueNotifier<bool> showTranslationHistory = ValueNotifier(true);
  final ValueNotifier<String> textSize = ValueNotifier('Medium');
  final ValueNotifier<String> cameraPreference = ValueNotifier('Back');
  final ValueNotifier<String> userName = ValueNotifier('');

  static const _textSizeMap = <String, double>{
    'Small': 0.85,
    'Medium': 1.0,
    'Large': 1.2,
  };

  Future<void> load() async {
    final db = await DbHelper().database;

    // Load settings from settings table
    final rows = await db.rawQuery('SELECT key, value FROM settings');
    final map = <String, String>{};
    for (final row in rows) {
      map[row['key'] as String] = row['value'] as String;
    }

    // Load user profile from users table
    final userRows = await db.query('users', limit: 1);
    final userNameFromDb = userRows.isNotEmpty ? userRows.first['name'] as String? ?? '' : '';
    final languageFromDb = userRows.isNotEmpty ? userRows.first['language_preference'] as String? ?? '' : '';

    textSize.value = map[_kTextSize] ?? 'Medium';
    textScale.value = _textSizeMap[textSize.value] ?? 1.0;
    ttsSpeed.value = double.tryParse(map[_kTtsSpeed] ?? '') ?? 0.5;
    language.value = languageFromDb.isNotEmpty ? languageFromDb : (map[_kLanguage] ?? 'Filipino');
    colorSchemeId.value = map[_kColorScheme] ?? 'indigo_depth';
    showTranslationHistory.value =
        map[_kShowHistory] == 'true' ? true : map[_kShowHistory] == 'false' ? false : true;
    cameraPreference.value = map[_kCameraPref] ?? 'Back';
    userName.value = userNameFromDb.isNotEmpty ? userNameFromDb : map[_kUserName] ?? '';

    final themeStr = map[_kThemeMode];
    if (themeStr == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (themeStr == 'light') {
      themeMode.value = ThemeMode.light;
    } else {
      themeMode.value = ThemeMode.system;
    }
  }

  Future<void> _save(String key, String value) async {
    final db = await DbHelper().database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  void setTextSize(String size) {
    textSize.value = size;
    textScale.value = _textSizeMap[size] ?? 1.0;
    _save(_kTextSize, size);
  }

  void setDarkMode(bool enabled) {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = mode;
    _save(_kThemeMode, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  void toggleDarkMode() {
    final newMode = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    themeMode.value = newMode;
    _save(_kThemeMode, newMode == ThemeMode.dark ? 'dark' : 'light');
  }

  void setTtsSpeed(double speed) {
    final clamped = speed.clamp(0.0, 1.0);
    ttsSpeed.value = clamped;
    _save(_kTtsSpeed, clamped.toStringAsFixed(2));
  }

  void setLanguage(String lang) {
    language.value = lang;
    _save(_kLanguage, lang);
    // Also update in users table
    _saveLanguageToDb(lang);
  }

  Future<void> _saveLanguageToDb(String lang) async {
    final db = await DbHelper().database;
    final existing = await db.query('users', limit: 1);
    if (existing.isNotEmpty) {
      await db.update('users', {'language_preference': lang}, where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  void setColorScheme(String id) {
    colorSchemeId.value = id;
    _save(_kColorScheme, id);
  }

  void setShowTranslationHistory(bool value) {
    showTranslationHistory.value = value;
    _save(_kShowHistory, value.toString());
  }

  void setCameraPreference(String pref) {
    cameraPreference.value = pref;
    _save(_kCameraPref, pref);
  }

  void setUserName(String name) {
    userName.value = name;
    _save(_kUserName, name);
    // Also update in users table
    _saveUserNameToDb(name);
  }

  Future<void> _saveUserNameToDb(String name) async {
    final db = await DbHelper().database;
    final existing = await db.query('users', limit: 1);
    if (existing.isNotEmpty) {
      await db.update('users', {'name': name}, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('users', {'name': name, 'role': 'deaf'});
    }
  }

  void dispose() {
    themeMode.dispose();
    textScale.dispose();
    ttsSpeed.dispose();
    language.dispose();
    colorSchemeId.dispose();
    showTranslationHistory.dispose();
    textSize.dispose();
    cameraPreference.dispose();
  }
}
