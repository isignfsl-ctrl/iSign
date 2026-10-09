import 'package:flutter_tts/flutter_tts.dart';
import '../../data/database/db_helper.dart';
import '../../data/models/user_model.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  UserModel? _currentUser;
  double _speed = 0.5;
  String _language = 'fil-PH';

  static const _languageMap = {
    'Filipino': 'fil-PH',
    'English': 'en-US',
  };

  static const _availableLanguages = [
    'Filipino',
    'English',
  ];

  List<String> get availableLanguages => List.unmodifiable(_availableLanguages);
  String get currentLanguage => _currentUser?.languagePreference ?? 'Filipino';
  double get currentSpeed => _speed;

  Future<void> init() async {
    try {
      final db = await DbHelper().database;
      final users = await db.query('users', orderBy: 'id DESC', limit: 1);
      if (users.isNotEmpty) {
        _currentUser = UserModel.fromMap(users.first);
      }
    } catch (_) {
      _currentUser = null;
    }
    await _applySettings();
  }

  Future<void> _applySettings() async {
    final lang = _currentUser?.languagePreference ?? 'Filipino';
    _language = _languageMap[lang] ?? 'fil-PH';
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speed);
    await _tts.setVolume(1.0);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _applySettings();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> setLanguage(String lang) async {
    final code = _languageMap[lang] ?? lang;
    final available = await _tts.isLanguageAvailable(code);
    if (available) {
      _language = code;
      await _tts.setLanguage(code);
    }
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speed);
  }

  Future<void> refreshUser() async {
    try {
      final db = await DbHelper().database;
      final users = await db.query('users', orderBy: 'id DESC', limit: 1);
      if (users.isNotEmpty) {
        _currentUser = UserModel.fromMap(users.first);
      }
    } catch (_) {
      _currentUser = null;
    }
    await _applySettings();
  }

  void dispose() {
    _tts.stop();
  }
}
