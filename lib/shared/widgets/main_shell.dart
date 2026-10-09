import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../features/home/home_screen.dart';
import '../../features/translate/translate_screen.dart';
import '../../features/signs/signs_screen.dart';
import '../../features/settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  DateTime? _lastBackPress;
  final _translateKey = GlobalKey<TranslateScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      if (_currentIndex == 1) {
        _translateKey.currentState?.stopCamera();
      }
      setState(() => _currentIndex = index);
      if (index == 1) {
        _translateKey.currentState?.startCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          Navigator.of(context).pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(onSwitchTab: _onTabTapped),
            TranslateScreen(key: _translateKey),
            SignsScreen(onSwitchTab: _onTabTapped),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.disabled,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.videocam_outlined),
              activeIcon: const Icon(Icons.videocam),
              label: 'Translate',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.pan_tool_outlined),
              activeIcon: const Icon(Icons.pan_tool),
              label: 'Signs',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
