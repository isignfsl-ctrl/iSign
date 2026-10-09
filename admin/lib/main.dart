import 'package:flutter/material.dart';
import 'services/admin_firebase_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fb = AdminFirebaseService();
  await fb.initialize();

  runApp(const AdminApp());
}
