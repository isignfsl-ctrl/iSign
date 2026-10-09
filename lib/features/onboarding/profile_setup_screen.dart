import 'package:flutter/material.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/database/db_helper.dart';
import '../../shared/widgets/main_shell.dart';
import '../../shared/services/app_settings.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedRole = 'deaf';
  String _selectedLanguage = 'Filipino';
  bool _isSaving = false;

  static const _roles = [
    ('deaf', 'Deaf User'),
    ('hearing', 'Hearing User'),
  ];

  static const _languages = [
    ('Filipino', 'Filipino'),
    ('English', 'English'),
  ];

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final db = await DbHelper().database;
    await db.insert('users', {
      'name': _nameController.text.trim(),
      'role': _selectedRole,
      'language_preference': _selectedLanguage,
    });

    // Update AppSettings with user name and language
    final appSettings = AppSettings();
    appSettings.setUserName(_nameController.text.trim());
    appSettings.setLanguage(_selectedLanguage);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This helps personalize your iSign experience.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                const Text(
                  'I am a...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: _roles.map(
                    (r) => ButtonSegment(value: r.$1, label: Text(r.$2)),
                  ).toList(),
                  selected: {_selectedRole},
                  onSelectionChanged: (v) =>
                      setState(() => _selectedRole = v.first),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Preferred Language',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: _languages.map(
                    (l) => ButtonSegment(value: l.$1, label: Text(l.$2)),
                  ).toList(),
                  selected: {_selectedLanguage},
                  onSelectionChanged: (v) =>
                      setState(() => _selectedLanguage = v.first),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
