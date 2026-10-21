import 'package:flutter/material.dart';
import 'package:isign_shared/isign_shared.dart';
import '../../core/themes/color_schemes.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/database/db_helper.dart';
import '../../data/database/seed_data.dart';
import '../../shared/services/app_settings.dart';
import '../../shared/services/sync_service.dart';
import '../../data/repositories/training_repository.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/services/catalog_notifier.dart';
import '../../shared/services/device_registration.dart';
import 'evaluation_report_screen.dart';
import 'submit_feedback_screen.dart';
import '../training/sign_recorder_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettings();
  final _syncService = SyncService();
  String? _appVersion;
  String? _modelVersion;
  bool _syncing = false;
  String _syncStatus = '';
  int _pendingSyncCount = 0;
  final _deviceReg = DeviceRegistration();
  String _profileName = '';
  String _profileRole = '';

  @override
  void initState() {
    super.initState();
    _loadVersions();
    _syncService.startMonitoring();
    _countPendingSync();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _deviceReg.getProfile();
    if (mounted)
      setState(() {
        _profileName = profile['name']!;
        _profileRole = profile['role']!;
      });
  }

  @override
  void dispose() {
    _syncService.stopMonitoring();
    super.dispose();
  }

  Future<void> _countPendingSync() async {
    try {
      final db = await DbHelper().database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM training_samples WHERE synced = 0');
      final count = (result.isNotEmpty ? result.first['cnt'] : 0) as int;
      if (mounted) setState(() => _pendingSyncCount = count);
    } catch (_) {}
  }

  Future<void> _loadVersions() async {
    final db = await DbHelper().database;

    final ver = await db.rawQuery('''
      SELECT version_name FROM model_versions
      WHERE version_name NOT IN ('seed_loaded', 'seed_v3', 'cat_repair_v1')
      ORDER BY deployed_at DESC LIMIT 1
    ''');

    if (!mounted) return;
    setState(() {
      _modelVersion =
          ver.isNotEmpty ? ver.first['version_name'] as String : 'FSL-v1.0';
      _appVersion = '1.0.0';
    });
  }

  Future<void> _syncAll() async {
    if (_syncing) return;
    final fb = FirebaseService();
    if (!fb.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase not configured.')),
        );
      }
      return;
    }

    setState(() {
      _syncing = true;
      _syncStatus = 'Step 1/4: Syncing training samples...';
    });

    try {
      final db = await DbHelper().database;
      final user = fb.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Not signed in to Firebase. Sync requires a Firebase account.')),
          );
        }
        setState(() {
          _syncing = false;
          _syncStatus = '';
        });
        return;
      }

      // Step 1: Upload training samples
      String? sampleUploadError;
      int sampleUploaded = 0;
      final rows = await db.query('training_samples', where: 'synced = 0');
      final samples = rows.map((r) => TrainingSample.fromMap(r)).toList();
      if (samples.isNotEmpty) {
        final result = await _syncService.batchSyncTrainingSamples(
          samples: samples,
          deviceId: 'device_${user.uid.hashCode.toRadixString(16)}',
          uid: user.uid,
          onProgress: (done, total) {
            if (mounted)
              setState(() => _syncStatus = 'Training: $done of $total groups');
          },
        );
        sampleUploaded = result.synced;
        if (!result.success) {
          sampleUploadError = result.error ?? 'unknown error';
        }
        // Mark only the groups that actually made it to Firestore.
        final okIds = result.sampleIds;
        if (okIds.isNotEmpty) {
          await db.update('training_samples', {'synced': 1},
              where: 'id IN (${okIds.join(',')})');
        }
      }

      // Step 2: Upload local signs to cloud catalog
      setState(() => _syncStatus = 'Step 2/4: Uploading sign catalog...');
      final signs = await db.query('fsl_signs');
      int uploaded = 0;
      for (final sign in signs) {
        final signId = sign['id'] as int;
        final signName = sign['sign_name'] as String;
        final description = sign['description'] as String? ?? '';
        final englishName = sign['english_name'] as String?;
        final englishDescription = sign['english_description'] as String?;
        final localCatId = (sign['category_id'] as int?) ?? 0;

        // Normalize to the canonical category ids (0-3) the admin panel
        // expects — local dbs may carry legacy autoincrement ids.
        int categoryId = localCatId;
        if (categoryId < 0 || categoryId >= SeedData.canonicalCategories.length) {
          final crows =
              await db.query('categories', where: 'id = ?', whereArgs: [localCatId]);
          final cname = crows.isNotEmpty
              ? (crows.first['category_name'] as String? ?? '')
              : '';
          categoryId = SeedData.nameToCanonicalId(cname) ?? 0;
        }

        final existing = await fb.firestore
            .collection('catalog')
            .where('signName', isEqualTo: signName)
            .limit(1)
            .get();

        final data = <String, dynamic>{
          'signId': signId,
          'signName': signName,
          'description': description,
          'english_name': englishName,
          'english_description': englishDescription,
          'categoryId': categoryId,
          'categoryName': SeedData.canonicalName(categoryId),
          'version': 1,
          'landmarkSamplePaths': <String>[],
          'updatedAt': DateTime.now().toIso8601String(),
          'updatedBy': 'app_sync',
        };

        if (existing.docs.isNotEmpty) {
          await fb.firestore
              .collection('catalog')
              .doc(existing.docs.first.id)
              .update(data);
        } else {
          await fb.firestore.collection('catalog').add(data);
        }
        uploaded++;
      }

      // Step 3: Pull cloud catalog to local
      setState(() => _syncStatus = 'Step 3/4: Downloading sign catalog...');
      final snapshot = await fb.firestore.collection('catalog').get();
      int added = 0, updated = 0;

      // Preload local categories for mapping cloud categoryIds
      final localCats = await db.query('categories');
      final catByName = <String, int>{};
      for (final cat in localCats) {
        catByName[cat['category_name'] as String] = cat['id'] as int;
      }
      // Hardcoded cloud category ID → (filipino_name, english_name) mapping
      final catNames = <int, List<String>>{
        0: ['Alpabeto', 'Alphabet'],
        1: ['Mga Karaniwang Parirala', 'Common Phrases'],
        2: ['Mga Bilang', 'Numbers'],
        3: ['Mga Pangunahing Galaw', 'Basic Gestures'],
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final signName = data['signName'] as String?;
        final description = data['description'] as String? ?? '';
        final englishName = data['english_name'] as String?;
        final englishDescription = data['english_description'] as String?;
        final cloudCatId = data['categoryId'] as int? ?? 0;

        // Map cloud category ID to local category ID
        int categoryId = cloudCatId;
        if (categoryId < 0 || categoryId >= SeedData.canonicalCategories.length) {
          categoryId = SeedData.nameToCanonicalId(
                  data['categoryName'] as String? ?? '') ??
              0;
        }
        final catEntry = catNames[categoryId];
        if (catEntry != null) {
          final filName = catEntry[0];
          final enName = catEntry[1];
          final existingId = catByName[filName];
          if (existingId != null) {
            categoryId = existingId;
          } else {
            final canonId = SeedData.nameToCanonicalId(filName);
            if (canonId != null) {
              await db.execute(
                  'INSERT OR IGNORE INTO categories (id, category_name, english_name) VALUES (?, ?, ?)',
                  [canonId, filName, enName]);
              categoryId = canonId;
            } else {
              categoryId = await db.insert('categories', {
                'category_name': filName,
                'english_name': enName,
              });
            }
            catByName[filName] = categoryId;
          }
        }

        if (signName == null) continue;

        final existing = await db
            .query('fsl_signs', where: 'sign_name = ?', whereArgs: [signName]);
        final row = <String, dynamic>{
          'sign_name': signName,
          'description': description,
          'english_name': englishName,
          'english_description': englishDescription,
          'category_id': categoryId,
        };
        if (existing.isNotEmpty) {
          await db.update('fsl_signs', row,
              where: 'sign_name = ?', whereArgs: [signName]);
          updated++;
        } else {
          await db.insert('fsl_signs', row);
          added++;
        }
      }

      // Step 4: Download approved training recordings
      setState(() =>
          _syncStatus = 'Step 4/4: Downloading approved training data...');
      final downloadResult = await _syncService.downloadApprovedRecordings(
        onProgress: (done, total) {
          if (mounted)
            setState(
                () => _syncStatus = 'Training: $done of $total recordings');
        },
      );

      // Refresh all training statuses
      await TrainingRepository().refreshAllTrainingStatus();

      CatalogNotifier.catalogCleared.value++;
      CatalogNotifier.trainingStatusChanged.value++;

      if (mounted) {
        setState(() => _syncStatus = sampleUploadError != null
            ? 'Sync done — sample upload FAILED'
            : 'Sync complete');
        final dlMsg = downloadResult.success
            ? ', downloaded ${downloadResult.synced} training recordings'
            : '';
        final sampleMsg = sampleUploadError != null
            ? ' | Sample upload FAILED: $sampleUploadError'
            : (sampleUploaded > 0
                ? ' | Uploaded $sampleUploaded sample group(s)'
                : '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              duration: const Duration(seconds: 6),
              content: Text(
                  'Uploaded $uploaded signs, pulled $added new + $updated updated$dlMsg$sampleMsg')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _syncStatus = 'Error: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
      await _countPendingSync();
    }
  }

  Future<void> _clearTable(String table, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear $label'),
        content: Text(
            'Are you sure you want to clear all $label? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DbHelper().database;
    await db.delete(table);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildSection('Preferences', _buildPreferences()),
          _buildSection('Profile', _buildProfile()),
          _buildSection('Training', _buildTraining()),
          _buildSection('Data Management', _buildDataManagement()),
          _buildSection('Cloud Sync', _buildCloudSync()),
          _buildSection('Evaluation & Feedback', _buildEvalFeedback()),
          _buildSection('About', _buildAbout()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        content,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPreferences() {
    return Column(
      children: [
        _prefTile(
          'Sign Text Language',
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Filipino', label: Text('Filipino')),
              ButtonSegment(value: 'English', label: Text('English')),
            ],
            selected: {_settings.language.value},
            onSelectionChanged: (v) =>
                setState(() => _settings.setLanguage(v.first)),
          ),
        ),
        _prefTile(
          'Text Size',
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Small', label: Text('Small')),
              ButtonSegment(value: 'Medium', label: Text('Medium')),
              ButtonSegment(value: 'Large', label: Text('Large')),
            ],
            selected: {_settings.textSize.value},
            onSelectionChanged: (v) {
              setState(() => _settings.setTextSize(v.first));
            },
          ),
        ),
        _prefTile(
          'TTS Speed',
          Row(
            children: [
              Text('Slow',
                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
              Expanded(
                child: Slider(
                  value: _settings.ttsSpeed.value,
                  min: 0.25,
                  max: 1.0,
                  divisions: 3,
                  label: [
                    'Slow',
                    'Normal',
                    'Fast'
                  ][(_settings.ttsSpeed.value * 4 - 1).round().clamp(0, 2)],
                  onChanged: (v) => setState(() => _settings.setTtsSpeed(v)),
                ),
              ),
              Text('Fast',
                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
            ],
          ),
        ),
        _prefTile(
          'Camera Preference',
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Back', label: Text('Back')),
              ButtonSegment(value: 'Front', label: Text('Front')),
            ],
            selected: {_settings.cameraPreference.value},
            onSelectionChanged: (v) {
              setState(() => _settings.setCameraPreference(v.first));
            },
          ),
        ),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Use dark theme throughout the app'),
          value: _settings.themeMode.value == ThemeMode.dark,
          onChanged: (v) => setState(() => _settings.setDarkMode(v)),
          secondary: Icon(
            _settings.themeMode.value == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SwitchListTile(
          title: const Text('Show Translation History'),
          subtitle:
              const Text('Display recent translations on the Home screen'),
          value: _settings.showTranslationHistory.value,
          onChanged: (v) =>
              setState(() => _settings.setShowTranslationHistory(v)),
          secondary: Icon(
            Icons.history,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        _buildColorPicker(),
      ],
    );
  }

  Widget _buildColorPicker() {
    final currentId = _settings.colorSchemeId.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Theme Color',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
        ...ColorSchemes.categories.map((category) {
          final presets = ColorSchemes.getByCategory(category);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: presets.map((preset) {
                    final isSelected = preset.id == currentId;
                    return GestureDetector(
                      onTap: () => _settings.setColorScheme(preset.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: preset.seedColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: preset.seedColor
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? context.textPrimary
                                  : context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _prefTile(String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          control,
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return Column(
      children: [
        ListTile(
          leading:
              Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
          title: Text(_profileName.isNotEmpty ? _profileName : 'Set your name'),
          subtitle: Text(_profileRole.isNotEmpty
              ? (_profileRole == 'deaf' ? 'Deaf User' : 'Hearing User')
              : 'Set your role'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editProfile(),
        ),
      ],
    );
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _profileName);
    String role = _profileRole.isNotEmpty ? _profileRole : 'deaf';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Your Name', prefixIcon: Icon(Icons.person)),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('I am a...',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'deaf', label: Text('Deaf User')),
                  ButtonSegment(value: 'hearing', label: Text('Hearing User')),
                ],
                selected: {role},
                onSelectionChanged: (v) => setDialogState(() => role = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await _deviceReg.updateProfile(nameCtrl.text.trim(), role);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    }

    nameCtrl.dispose();
  }

  Widget _buildTraining() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.fitness_center,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Sign Recorder'),
          subtitle: const Text('Record hand landmarks for FSL training data'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SignRecorderScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildDataManagement() {
    return Column(
      children: [
        ListTile(
          leading:
              Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
          title: const Text('Clear Translation History'),
          subtitle: const Text('Remove all saved translation sessions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _clearTable('translations', 'Translation History'),
        ),
        ListTile(
          leading: Icon(Icons.videocam,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Clear Saved Recordings'),
          subtitle: const Text('Remove all recorded video sessions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _clearTable('recordings', 'Saved Recordings'),
        ),
      ],
    );
  }

  Future<void> _clearLocalSigns() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Local Signs'),
        content: const Text(
          'This will delete ALL local signs permanently. '
          'Use Sync to restore signs from the cloud. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear Everything',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _syncStatus = 'Clearing local signs...');

    try {
      final db = await DbHelper().database;
      await db.delete('sign_media');
      await db.delete('fsl_signs');
      await db.delete('categories');
      await db.delete('model_versions',
          where: 'version_name IN (?, ?)',
          whereArgs: ['seed_v3', 'cat_repair_v1']);

      CatalogNotifier.catalogCleared.value++;

      if (mounted) {
        setState(() => _syncStatus = 'Local signs cleared');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local signs deleted')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _syncStatus = 'Error: $e');
    }
  }

  Widget _buildCloudSync() {
    final theme = Theme.of(context);
    final online = _syncService.isConnected;
    final connType = _syncService.connectionType;
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.sync, color: theme.colorScheme.primary),
          title: const Text('Sync Everything'),
          subtitle: Text(
            _syncing
                ? _syncStatus
                : _syncStatus.isNotEmpty
                    ? _syncStatus
                    : 'Upload + download signs | $connType',
          ),
          trailing: _syncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(online ? Icons.cloud : Icons.cloud_off,
                  color: online ? Colors.blue : Colors.grey),
          onTap: _syncing ? null : _syncAll,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
          title: Text('Clear Local Signs',
              style: TextStyle(color: theme.colorScheme.error)),
          subtitle: const Text('Delete all local signs permanently'),
          onTap: _syncing ? null : _clearLocalSigns,
        ),
      ],
    );
  }

  Widget _buildEvalFeedback() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.assessment,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('View Evaluation Report'),
          subtitle: const Text('Accuracy, inference speed, and export options'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EvaluationReportScreen()),
          ),
        ),
        ListTile(
          leading: Icon(Icons.feedback,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Submit Feedback'),
          subtitle: const Text('Rate a sign and share your thoughts'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubmitFeedbackScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAbout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/iSign.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          const Text('iSign',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Version $_appVersion',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _aboutRow('Model', _modelVersion ?? 'FSL-v1.0'),
                const Divider(height: 16),
                const Text(
                  'Purpose',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'iSign is an offline AI-driven Filipino Sign Language (FSL) '
                  'recognition system that translates gestures into text '
                  'and speech, helping bridge communication between deaf '
                  'and hearing individuals.',
                  style: TextStyle(
                      fontSize: 14, color: context.textSecondary, height: 1.5),
                ),
                const Divider(height: 16),
                const Text(
                  'Team',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Developed as a capstone project for assisting deaf '
                  'communication through Filipino Sign Language translation.',
                  style: TextStyle(
                      fontSize: 14, color: context.textSecondary, height: 1.5),
                ),
                const Divider(height: 16),
                const Text(
                  'FSL Usage Guide',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Position your hands clearly in frame\n'
                  '• Ensure adequate lighting\n'
                  '• Perform signs at a moderate pace\n'
                  '• Keep background simple and non-distracting',
                  style: TextStyle(
                      fontSize: 14, color: context.textSecondary, height: 1.5),
                ),
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber,
                          color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Accuracy depends on lighting, camera quality, and '
                          'user positioning. This app is limited to predefined '
                          'FSL gestures and does not replace professional '
                          'interpreters.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            height: 1.4,
                          ),
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

  Widget _aboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 14, color: context.textSecondary)),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
