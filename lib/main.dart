import 'package:flutter/material.dart';
import 'app.dart';
import 'shared/services/app_settings.dart';
import 'shared/services/firebase_service.dart';
import 'shared/services/device_registration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted settings
  await AppSettings().load();

  // Try to initialize Firebase; graceful failure if not configured
  final fs = FirebaseService();
  try {
    await fs.initialize();
    await _signInAnonymously(fs);
    _registerDevice(fs);
  } catch (_) {
    // Firebase not configured — app works offline
  }

  runApp(const App());
}

Future<void> _signInAnonymously(FirebaseService fs) async {
  try {
    if (fs.auth.currentUser == null) {
      await fs.auth.signInAnonymously();
    }
  } catch (_) {
    // Best-effort — app works without auth
  }
}

void _registerDevice(FirebaseService fs) {
  try {
    final user = fs.auth.currentUser;
    if (user == null) return;
    final deviceId = 'device_${user.uid.hashCode.toRadixString(16)}';
    DeviceRegistration().registerDevice(deviceId, 'Realme RMX3686');
  } catch (_) {
    // Device registration is best-effort
  }
}
