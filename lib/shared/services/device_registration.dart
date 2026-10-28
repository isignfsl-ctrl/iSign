import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/db_helper.dart';

/// Single source of truth for this installation's device identity.
///
/// The device ID is generated once and persisted in two stores (SharedPreferences
/// + the local `settings` table) so it stays stable across app restarts, across
/// anonymous-auth UID churn, and even when only one of the two stores is
/// reachable (e.g. inside the WorkManager background isolate).
///
/// Every Firestore device document, every recording, and every sync now uses
/// this one ID — previously callers each derived their own variant
/// (`device_<uidHash>`, `device_<uidHash>_<timestamp>`, raw `uid`), which
/// produced duplicate/ghost device rows and broke trust-count attribution.
class DeviceRegistration {
  DeviceRegistration._();

  static final DeviceRegistration _instance = DeviceRegistration._();
  factory DeviceRegistration() => _instance;

  static const _kDeviceIdKey = 'stable_device_id';
  static const _kRegisteredAtKey = 'device_registered_at';
  static const _channel = MethodChannel('isign.installer');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedId;
  String? _cachedModel;
  static String? _sharedModel;

  /// Stable, install-scoped device identifier (e.g. `dev_9f3a71c4...`).
  Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;

    var id = await _readPersistedId();
    if (id == null || id.isEmpty) {
      id = 'dev_${_randomHex(16)}';
      await _persistId(id);
    }
    _cachedId = id;
    return id;
  }

  /// Real hardware model, e.g. `Realme RMX3686` — read natively so different
  /// phones no longer report the same hardcoded string. Cached per process.
  Future<String> getDeviceModel() async {
    if (_cachedModel != null) return _cachedModel!;
    if (_sharedModel != null) {
      _cachedModel = _sharedModel;
      return _cachedModel!;
    }

    String model = '';
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (info != null) {
        final manufacturer = (info['manufacturer'] as String? ?? '').trim();
        final deviceModel = (info['model'] as String? ?? '').trim();
        // Some vendors already prefix the model with the brand (e.g. "Realme
        // RMX3686"), others don't — only prepend when it's missing.
        model = (deviceModel.toLowerCase().startsWith(manufacturer.toLowerCase()) ||
                manufacturer.isEmpty)
            ? deviceModel
            : '$manufacturer $deviceModel';
      }
    } catch (_) {
      // Channel unavailable (unit tests, other platforms) — fall through.
    }

    if (model.isEmpty) model = 'Unknown device';
    _sharedModel = model;
    _cachedModel = model;
    return model;
  }

  /// Register this device under the current account and bump the per-launch
  /// activity counter the admin panel uses to rank active devices.
  ///
  /// Writes the SAME document every launch (stable ID + merge), so no duplicate
  /// rows accumulate. Returns null on success, otherwise an error string.
  Future<String?> registerDevice() async {
    final user = _auth.currentUser;
    if (user == null) return 'Not signed in';
    if (!await _isOnline()) return 'Offline';

    try {
      final deviceId = await getDeviceId();
      final model = await getDeviceModel();

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

      final now = DateTime.now().toIso8601String();
      final registeredAt = await _getOrCreateRegisteredAt();

      await _firestore.collection('devices').doc(deviceId).set({
        'ownerUid': user.uid,
        'ownerEmail': user.email,
        'ownerName': ownerName,
        'userType': userType,
        'model': model,
        'status': 'active',
        'registeredAt': registeredAt,
        'registeredAtMs': DateTime.parse(registeredAt).millisecondsSinceEpoch,
        'lastSync': now,
        'lastActive': now,
        'activeSessions': FieldValue.increment(1),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

      await _firestore.collection('users').doc(user.uid).set({
        'devices': FieldValue.arrayUnion([deviceId]),
        'lastActive': now,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Refresh the activity stamp without re-registering (cheap "device is alive"
  /// signal the admin panel can sort on).
  Future<void> touchActivity() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!await _isOnline()) return;
    try {
      final deviceId = await getDeviceId();
      await _firestore.collection('devices').doc(deviceId).set({
        'lastActive': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// True when the device has any network route.
  ///
  /// Firestore writes issued offline stay pending forever (a write Future only
  /// resolves once the server acknowledges it), so callers skip them instead
  /// of leaving futures — and an ever-growing offline write queue — behind.
  Future<bool> _isOnline() async {
    try {
      final status = await Connectivity().checkConnectivity();
      return status.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Unknown state — let the call proceed and rely on its own timeout.
      return true;
    }
  }

  Future<void> updateProfile(String name, String role) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final db = await DbHelper().database;
      final existing = await db.query('users', limit: 1);
      if (existing.isNotEmpty) {
        await db.update('users', {'name': name, 'role': role},
            where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        await db.insert('users', {'name': name, 'role': role});
      }

      // Same stable doc as registerDevice() — never a timestamped doc, which
      // is what used to create a fresh duplicate on every profile edit.
      final deviceId = await getDeviceId();
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

  // --- persistence -------------------------------------------------------

  Future<String?> _readPersistedId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kDeviceIdKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}

    try {
      final db = await DbHelper().database;
      final rows =
          await db.query('settings', where: 'key = ?', whereArgs: [_kDeviceIdKey]);
      final v = rows.isNotEmpty ? rows.first['value'] as String? : null;
      if (v != null && v.isNotEmpty) {
        // Re-hydrate SharedPreferences so the fast path works next time.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kDeviceIdKey, v);
        } catch (_) {}
        return v;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persistId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDeviceIdKey, id);
    } catch (_) {}
    try {
      final db = await DbHelper().database;
      await db.rawInsert(
          'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
          [_kDeviceIdKey, id]);
    } catch (_) {}
  }

  /// First-ever registration time for this install, remembered locally so it
  /// isn't overwritten on later launches.
  Future<String> _getOrCreateRegisteredAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kRegisteredAtKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_kRegisteredAtKey, now);
      return now;
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  static String _randomHex(int chars) {
    final rnd = Random.secure();
    final sb = StringBuffer();
    for (var i = 0; i < chars; i++) {
      sb.write(rnd.nextInt(16).toRadixString(16));
    }
    return sb.toString();
  }
}
