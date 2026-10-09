import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/database/db_helper.dart';
import '../../shared/services/app_settings.dart';
import 'translation_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int index)? onSwitchTab;

  const HomeScreen({super.key, this.onSwitchTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentTranslations = [];
  bool _loaded = false;
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  static const _trivia = [
    _TriviaData(
      icon: Icons.info_outline,
      text: 'There are over 108 sign languages worldwide — each country has its own.',
    ),
    _TriviaData(
      icon: Icons.hearing_outlined,
      text: 'Filipino Sign Language (FSL) is used by over 12,000 deaf Filipinos.',
    ),
    _TriviaData(
      icon: Icons.language_outlined,
      text: 'Sign language is NOT universal — FSL is different from ASL, BSL, and others.',
    ),
    _TriviaData(
      icon: Icons.groups_outlined,
      text: 'Only about 55% of deaf Filipinos can communicate with hearing people.',
    ),
    _TriviaData(
      icon: Icons.favorite_outline,
      text: 'Learning basic sign language fosters inclusion and bridges the communication gap.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTipTimer();
  }

  void _startTipTimer() {
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _currentTipIndex = (_currentTipIndex + 1) % _trivia.length);
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadData();
      _loaded = true;
    }
  }

  Future<void> _loadData() async {
    final db = await DbHelper().database;

    final recent = await db.rawQuery('''
      SELECT t.id, t.created_at, t.mode,
             GROUP_CONCAT(td.translated_text, ' ') AS full_text
      FROM translations t
      LEFT JOIN translation_details td ON td.translation_id = t.id
      GROUP BY t.id
      ORDER BY t.created_at DESC
      LIMIT 5
    ''');

    if (!mounted) return;
    setState(() => _recentTranslations = recent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/iSign-icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text('iSign'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _buildHowToUse(),
            const SizedBox(height: 16),
            _buildStartButton(),
            const SizedBox(height: 20),
            _buildRecentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToUse() {
    final steps = [
      _StepData(
        icon: Icons.videocam_outlined,
        label: 'Point Camera',
        description: 'Position your device so your hands are clearly visible in the frame',
        number: '1',
      ),
      _StepData(
        icon: Icons.back_hand_outlined,
        label: 'Show Sign',
        description: 'Perform an FSL gesture clearly — the AI reads hand shapes and movements',
        number: '2',
      ),
      _StepData(
        icon: Icons.notes_outlined,
        label: 'Read Translation',
        description: 'View the text and hear speech output of your recognized sign',
        number: '3',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Use',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildStepCard(steps[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(_StepData step) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(step.icon, size: 24, color: AppColors.primary),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      step.number,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            step.description,
            style: TextStyle(
              fontSize: 10,
              color: context.textSecondary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => widget.onSwitchTab?.call(1),
        icon: const Icon(Icons.videocam, size: 20),
        label: const Text(
          'Start Translate',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    final showHistory = AppSettings().showTranslationHistory.value;

    if (!showHistory || _recentTranslations.isEmpty) {
      return _buildTriviaSection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Translations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ..._recentTranslations.map((t) {
            final id = t['id'] as int;
            final createdAt = t['created_at'] as String? ?? '';
            final mode = t['mode'] as String? ?? 'realtime';
            final fullText = t['full_text'] as String? ?? '';
            final displayText = fullText.isNotEmpty ? fullText : 'Untitled';
            final displayTime = createdAt.length >= 16
                ? '${createdAt.substring(0, 10)}  ${createdAt.substring(11, 16)}'
                : createdAt;
            final isSpeech = mode == 'speech';
            final modeIcon = isSpeech ? Icons.mic : Icons.videocam;

            return InkWell(
              onTap: () async {
                final deleted = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TranslationDetailScreen(translationId: id),
                  ),
                );
                if (deleted == true) _loadData();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isSpeech
                                ? Colors.blue
                                : AppColors.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(modeIcon, size: 18,
                          color: isSpeech ? Colors.blue : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                displayTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isSpeech
                                          ? Colors.blue
                                          : AppColors.primary)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSpeech ? 'Speech' : 'Gesture',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSpeech
                                        ? Colors.blue.shade700
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18,
                        color: context.textSecondary),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTriviaSection() {
    final trivia = _trivia[_currentTipIndex];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(trivia.icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Did You Know?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trivia.text,
            style: TextStyle(
              fontSize: 13,
              color: context.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _trivia.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentTipIndex == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentTipIndex == i
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  final String description;
  final String number;

  const _StepData({required this.icon, required this.label, required this.description, required this.number});
}

class _TriviaData {
  final IconData icon;
  final String text;

  const _TriviaData({required this.icon, required this.text});
}
