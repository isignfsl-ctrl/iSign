import 'dart:async';

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

  // Try to initialize Firebase; graceful failure if not configured.
  // This step only reads bundled config, but keep a ceiling on it so a
  // misbehaving Play services install can never hold the splash screen.
  final fs = FirebaseService();
  try {
    await fs.initialize().timeout(const Duration(seconds: 10));
  } catch (_) {
    // Firebase not configured — app works offline
  }

  runApp(const App());

  // Everything below touches the network and MUST NOT gate the first frame.
  // Offline, a Firestore write is queued locally but its Future only resolves
  // once the server acknowledges it — which may be never. Awaiting that here
  // froze startup on any device that had been online before (those carry a
  // signed-in user, so registerDevice() waited forever on its set() calls).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      _firebaseBootstrap(fs)
          .timeout(const Duration(seconds: 20))
          .catchError((_) {}),
    );
  });

  // Enable background training-sample uploads (best-effort)
  unawaited(_initBackgroundUploads());
}

/// Sign in and register the device in the background, each step individually
/// guarded so one hanging call cannot stall the rest.
Future<void> _firebaseBootstrap(FirebaseService fs) async {
  await _signInAnonymously(fs);
  await _registerDevice(fs);
}

Future<void> _initBackgroundUploads() async {
  try {
    await TrainingUploadService.initialize();
  } catch (_) {
    // WorkManager unavailable — manual sync still works
  }
}

Future<void> _signInAnonymously(FirebaseService fs) async {
  try {
    if (fs.auth.currentUser == null) {
      await fs.auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 10));
    }
  } catch (_) {
    // Best-effort — app works without auth
  }
}

Future<void> _registerDevice(FirebaseService fs) async {
  try {
    final user = fs.auth.currentUser;
    if (user == null) return;
    // Stable install-scoped ID + real hardware model — no hardcoded device
    // name, no per-launch duplicate documents in the admin panel.
    await DeviceRegistration().registerDevice();
  } catch (_) {
    // Device registration is best-effort
  }
}
