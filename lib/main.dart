import 'package:flutter/material.dart';
import 'app.dart';
import 'data/database/db_helper.dart';
import 'data/database/seed_data.dart';
import 'shared/services/app_settings.dart';
import 'shared/services/firebase_service.dart';
import 'shared/services/device_registration.dart';
import 'shared/services/training_upload_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted settings
  await AppSettings().load();

  // One-time category repair (canonical ids 0-3, non-destructive)
  try {
    await SeedData().repairCategories(await DbHelper().database);
  } catch (_) {
    // Best-effort — sync normalizes categories as well
  }

  // Try to initialize Firebase; graceful failure if not configured
  final fs = FirebaseService();
  try {
    await fs.initialize();
    await _signInAnonymously(fs);
    _registerDevice(fs);
  } catch (_) {
    // Firebase not configured — app works offline
  }

  // Enable background training-sample uploads (best-effort)
  try {
    await TrainingUploadService.initialize();
  } catch (_) {
    // WorkManager unavailable — manual sync still works
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
