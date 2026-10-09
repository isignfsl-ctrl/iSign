import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/database/db_helper.dart';

class DeviceRegistration {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register this device under the current user's account.
  /// Returns the deviceId (a UUID generated once and persisted).
  Future<String?> registerDevice(String deviceId, String model) async {
    final user = _auth.currentUser;
    if (user == null) return 'Not signed in';

    try {
      String ownerName = '';
      String userType = '';

      try {
        final db = await DbHelper().database;
        final rows = await db.query('users', limit: 1);
        if (rows.isNotEmpty) {
          ownerName = rows.first['name'] as String? ?? '';
          userType = rows.first['role'] as String? ?? '';
        }
      } catch (_) {}

      await _firestore.collection('devices').doc(deviceId).set({
        'ownerUid': user.uid,
        'ownerEmail': user.email,
        'ownerName': ownerName,
        'userType': userType,
        'model': model,
        'status': 'active',
        'registeredAt': DateTime.now().toIso8601String(),
        'lastSync': DateTime.now().toIso8601String(),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'devices': FieldValue.arrayUnion([deviceId]),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateProfile(String name, String role) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final db = await DbHelper().database;
      final existing = await db.query('users', limit: 1);
      if (existing.isNotEmpty) {
        await db.update('users', {'name': name, 'role': role}, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        await db.insert('users', {'name': name, 'role': role});
      }

      final deviceId = 'device_${user.uid.hashCode.toRadixString(16)}';
      await _firestore.collection('devices').doc(deviceId).set({
        'ownerName': name,
        'userType': role,
        'ownerUid': user.uid,
        'ownerEmail': user.email ?? '',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<Map<String, String>> getProfile() async {
    try {
      final db = await DbHelper().database;
      final rows = await db.query('users', limit: 1);
      if (rows.isNotEmpty) {
        return {
          'name': rows.first['name'] as String? ?? '',
          'role': rows.first['role'] as String? ?? '',
        };
      }
    } catch (_) {}
    return {'name': '', 'role': ''};
  }

  static String generateDeviceId(String androidId) {
    return 'device_${androidId.hashCode.toRadixString(16)}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
