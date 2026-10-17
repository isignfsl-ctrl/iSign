import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart' show DefaultFirebaseOptions;

class AdminFirebaseService {
  static final AdminFirebaseService _instance = AdminFirebaseService._();
  factory AdminFirebaseService() => _instance;
  AdminFirebaseService._();

  bool _initialized = false;
  String? _error;

  bool get isInitialized => _initialized;
  String? get error => _error;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      _initialized = true;
    } catch (e) {
      _error = e.toString();
    }
  }

  FirebaseFirestore get firestore {
    if (!_initialized) throw StateError('Firebase not initialized: $_error');
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get auth {
    if (!_initialized) throw StateError('Firebase not initialized: $_error');
    return FirebaseAuth.instance;
  }

  FirebaseStorage get storage {
    if (!_initialized) throw StateError('Firebase not initialized: $_error');
    return FirebaseStorage.instance;
  }
}
