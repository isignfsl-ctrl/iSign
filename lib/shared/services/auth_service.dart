import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'contributor',
        'createdAt': DateTime.now().toIso8601String(),
        'devices': [],
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signInWithGitHub() async {
    try {
      final provider = GithubAuthProvider();
      await _auth.signInWithPopup(provider);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<List<String>> registerDevice(String uid, String deviceId) async {
    await _firestore.collection('users').doc(uid).update({
      'devices': FieldValue.arrayUnion([deviceId]),
    });
    await _firestore.collection('devices').doc(deviceId).set({
      'ownerUid': uid,
      'ownerEmail': _auth.currentUser?.email,
      'lastSync': DateTime.now().toIso8601String(),
      'status': 'active',
      'model': '',
      'registeredAt': DateTime.now().toIso8601String(),
    });
    final userDoc = await _firestore.collection('users').doc(uid).get();
    return List<String>.from(userDoc.data()?['devices'] ?? []);
  }
}