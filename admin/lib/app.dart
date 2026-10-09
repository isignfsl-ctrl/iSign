import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/admin_firebase_service.dart';
import 'services/admin_auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fb = AdminFirebaseService();
    if (!fb.isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(fb.error != null ? 'Firebase error: ${fb.error}' : 'Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    final auth = AdminAuthService();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iSign Admin',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: StreamBuilder<User?>(
        stream: auth.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
