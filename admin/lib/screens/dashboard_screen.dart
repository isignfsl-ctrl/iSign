// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_firebase_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_home_screen.dart';
import 'recordings_screen.dart';
import 'catalog_screen.dart';
import 'devices_screen.dart';
import 'users_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _auth = AdminAuthService();
  final _fb = AdminFirebaseService();
  String? _role;
  final _builtScreens = <int>{0};
  int _previousIndex = 0;
  int _pendingCount = 0;
  bool _isOnline = html.window.navigator.onLine ?? true;

  static const _navItems = [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.quiz_outlined, activeIcon: Icons.quiz, label: 'Recordings'),
    (icon: Icons.book_outlined, activeIcon: Icons.book, label: 'Catalog'),
    (icon: Icons.phone_android_outlined, activeIcon: Icons.phone_android, label: 'Devices'),
    (icon: Icons.people_outline, activeIcon: Icons.people, label: 'Users'),
  ];

  static const _screenTitles = [
    'Dashboard', 'Recordings', 'Catalog', 'Devices', 'Users',
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const DashboardHomeScreen();
      case 1: return const RecordingsScreen();
      case 2: return const CatalogScreen();
      case 3: return const DevicesScreen();
      case 4: return const UsersScreen();
      default: return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRole();
    _listenPending();
    html.window.onOnline.listen((_) { if (mounted) setState(() => _isOnline = true); });
    html.window.onOffline.listen((_) { if (mounted) setState(() => _isOnline = false); });
  }

  Future<void> _loadRole() async {
    final role = await _auth.getUserRole();
    if (mounted) setState(() => _role = role);
  }

  void _listenPending() {
    _fb.firestore.collection('recordings').where('status', isEqualTo: 'pending').snapshots().listen((snap) {
      if (mounted) setState(() => _pendingCount = snap.docs.length);
    });
  }

  void _navigateTo(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _builtScreens.add(index);
    });
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPwdCtl = TextEditingController();
    final newPwdCtl = TextEditingController();
    final confirmPwdCtl = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              TextField(
                controller: currentPwdCtl,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPwdCtl,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwdCtl,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    final user = _auth.currentUser;
                    if (user?.email == null) return;
                    Navigator.of(ctx).pop();
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: user!.email!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Password reset link sent to your email')),
                      );
                    }
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (newPwdCtl.text != confirmPwdCtl.text) {
                  setDialogState(
                      () => error = 'New passwords do not match');
                  return;
                }
                if (newPwdCtl.text.length < 6) {
                  setDialogState(() =>
                      error = 'Password must be at least 6 characters');
                  return;
                }
                try {
                  final user = _auth.currentUser;
                  if (user == null || user.email == null) return;
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPwdCtl.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPwdCtl.text);
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } on FirebaseAuthException catch (e) {
                  setDialogState(
                      () => error = e.message ?? 'Failed to change password');
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );

    currentPwdCtl.dispose();
    newPwdCtl.dispose();
    confirmPwdCtl.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true) await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return isWide ? _buildWideLayout() : _buildNarrowLayout();
  }

  Widget _buildWideLayout() {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.statusRejected.withValues(alpha: 0.12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: AppColors.statusRejected),
                  const SizedBox(width: 6),
                  Text('Connection lost. Data may be stale.', style: TextStyle(fontSize: 12, color: AppColors.statusRejected, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(theme),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _buildBreadcrumb(theme),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                            return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
                          },
                          child: KeyedSubtree(key: ValueKey(_currentIndex), child: _buildScreen(_currentIndex)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    final sidebarColor = theme.brightness == Brightness.dark ? AppColors.surfaceDark : theme.colorScheme.surfaceContainerLow;
    return Container(
      width: 220, color: sidebarColor,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.pan_tool, color: theme.colorScheme.primary, size: 28),
          const SizedBox(height: 4),
          Text('iSign Admin', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final selected = _currentIndex == index;
                final badge = index == 1 && _pendingCount > 0 ? _pendingCount : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _navigateTo(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(selected ? item.activeIcon : item.icon, size: 20,
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(item.label, style: TextStyle(fontSize: 14,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.statusPending.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$badge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.statusPending)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.person, size: 16, color: theme.colorScheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_auth.currentUser?.email ?? 'Admin', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                if (_role != null) Text(_role!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
              IconButton(icon: const Icon(Icons.lock_outline, size: 18), tooltip: 'Change Password', onPressed: _showChangePasswordDialog, visualDensity: VisualDensity.compact),
              IconButton(icon: const Icon(Icons.logout, size: 18), tooltip: 'Sign out', onPressed: _logout, visualDensity: VisualDensity.compact),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant))),
      child: Row(children: [
        Icon(Icons.home_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(_screenTitles[_currentIndex], style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        if (_currentIndex == 1 && _pendingCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.statusPending.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('$_pendingCount pending', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.statusPending)),
          ),
        ],
      ]),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(_screenTitles[_currentIndex]),
          if (_currentIndex == 1 && _pendingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.statusPending.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('$_pendingCount pending', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.statusPending)),
            ),
          ],
        ]),
        actions: [
          if (_role != null) Chip(label: Text(_role!), visualDensity: VisualDensity.compact),
          IconButton(icon: const Icon(Icons.lock_outline), tooltip: 'Change Password', onPressed: _showChangePasswordDialog),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.statusRejected.withValues(alpha: 0.12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: AppColors.statusRejected),
                  const SizedBox(width: 6),
                  Text('Connection lost.', style: TextStyle(fontSize: 12, color: AppColors.statusRejected, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: Offset(_currentIndex > _previousIndex ? 0.05 : -0.05, 0), end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
              },
              child: KeyedSubtree(key: ValueKey(_currentIndex), child: _buildScreen(_currentIndex)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateTo,
        animationDuration: const Duration(milliseconds: 300),
        destinations: _navItems.asMap().entries.map((entry) {
          final badge = entry.key == 1 && _pendingCount > 0 ? _pendingCount : null;
          return NavigationDestination(
            icon: badge != null
                ? Badge(label: Text('$badge'), child: Icon(entry.value.icon))
                : Icon(entry.value.icon),
            selectedIcon: badge != null
                ? Badge(label: Text('$badge'), child: Icon(entry.value.activeIcon))
                : Icon(entry.value.activeIcon),
            label: entry.value.label,
          );
        }).toList(),
      ),
    );
  }
}
