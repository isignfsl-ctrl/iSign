import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart' show DefaultFirebaseOptions;

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  String? _initError;

  FirebaseApp? _app;
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  FirebaseStorage? _storage;

  bool get isInitialized => _app != null;
  String? get initError => _initError;

  FirebaseFirestore get firestore {
    if (_firestore == null) throw StateError('Firebase not initialized: $_initError');
    return _firestore!;
  }

  FirebaseAuth get auth {
    if (_auth == null) throw StateError('Firebase not initialized: $_initError');
    return _auth!;
  }

  FirebaseStorage get storage {
    if (_storage == null) throw StateError('Firebase not initialized: $_initError');
    return _storage!;
  }

  Future<void> initialize() async {
    if (_app != null) return;
    try {
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firestore = FirebaseFirestore.instanceFor(app: _app!);
      _auth = FirebaseAuth.instanceFor(app: _app!);
      _storage = FirebaseStorage.instanceFor(app: _app!);
    } catch (e) {
      _initError = e.toString();
    }
  }
}