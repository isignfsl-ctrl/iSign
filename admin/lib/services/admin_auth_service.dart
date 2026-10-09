import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_firebase_service.dart';

class AdminAuthService {
  final AdminFirebaseService _fb = AdminFirebaseService();

  User? get currentUser => _fb.auth.currentUser;
  bool get isSignedIn => _fb.auth.currentUser != null;
  Stream<User?> get authStateChanges => _fb.auth.authStateChanges();

  Future<String?> signIn(String email, String password) async {
    try {
      await _fb.auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    }
  }

  Future<void> signOut() async {
    await _fb.auth.signOut();
  }

  Future<String?> getUserRole() async {
    final user = _fb.auth.currentUser;
    if (user == null) return null;
    final doc = await _fb.firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role'] as String?;
  }
}
