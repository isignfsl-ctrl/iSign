import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/models/category_model.dart';
import '../../data/models/fsl_sign_model.dart';
import '../../data/database/db_helper.dart';
import '../../data/repositories/training_repository.dart';
import '../../shared/services/sign_translator.dart';
import '../training/sign_recorder_screen.dart';

Color _categoryColor(String name) {
  switch (name.toLowerCase()) {
    case 'alpabeto':
      return const Color(0xFF4CAF50);
    case 'mga karaniwang parirala':
      return const Color(0xFF2196F3);
    case 'mga bilang':
      return const Color(0xFFFF9800);
    case 'mga pangunahing galaw':
      return const Color(0xFFFF5722);
    default:
      return const Color(0xFF607D8B);
  }
}

class SignDetailScreen extends StatefulWidget {
  final FslSignModel sign;
  final String? categoryName;
  final VoidCallback? onPractice;

  const SignDetailScreen({
    super.key,
    required this.sign,
    this.categoryName,
    this.onPractice,
  });

  @override
  State<SignDetailScreen> createState() => _SignDetailScreenState();
}

class _SignDetailScreenState extends State<SignDetailScreen> {
  final _translator = SignTranslator();
  final _trainingRepo = TrainingRepository();
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  List<CategoryModel> _categories = [];
  int _sampleCount = 0;
  int _refCount = 0;
  bool _isTrained = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadCategories();
    _loadTrainingInfo();
  }

  Future<void> _loadTrainingInfo() async {
    final signId = widget.sign.id;
    if (signId == null) return;
    final sampleCount = await _trainingRepo.getSampleCount(signId);
    final refCount = await _trainingRepo.getReferenceCount(signId);
    final status = await _trainingRepo.getTrainingStatus(signId);
    if (mounted) {
      setState(() {
        _sampleCount = sampleCount;
        _refCount = refCount;
        _isTrained = status == 'trained' ||
            refCount >= TrainingRepository.minSamplesForTrained;
      });
    }
  }

  Future<void> _loadCategories() async {
    final db = await DbHelper().database;
    final maps = await db.query('categories');
    if (mounted) {
      setState(() =>
          _categories = maps.map((m) => CategoryModel.fromMap(m)).toList());
    }
  }

  Future<void> _initVideo() async {
    final assetPath = 'assets/signs/videos/${widget.sign.signName}.mp4';
    try {
      _videoController = VideoPlayerController.asset(assetPath);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      if (!mounted) return;
      setState(() => _videoReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoReady = false);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(widget.categoryName ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(_translator.signName(widget.sign)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoSection(),
            const SizedBox(height: 16),
            _buildGuideSection(catColor),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildInfoHeader(catColor),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrainingStatus(),
                  const SizedBox(height: 16),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  _buildActionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    if (_videoReady && _videoController != null) {
      return Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              _PlayPauseOverlay(controller: _videoController!),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 220,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam,
            size: 48,
            color: context.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            'Demo video not available',
            style: TextStyle(
              fontSize: 15,
              color: context.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add ${widget.sign.signName}.mp4 to assets/signs/videos/',
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(Color catColor) {
    final displayName = _translator.signName(widget.sign);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: catColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    catColor.withValues(alpha: 0.2),
                    catColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: catColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _handShapeInstruction(widget.sign.signName),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _handShapeInstruction(String signName) {
    return 'Tap "Practice" to test this sign with your camera';
  }

  Widget _buildInfoHeader(Color catColor) {
    final catModel = widget.sign.categoryId != null
        ? _categories.where((c) => c.id == widget.sign.categoryId).firstOrNull
        : null;
    final catDisplay = catModel != null
        ? _translator.categoryName(catModel)
        : (widget.categoryName ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        catDisplay.isNotEmpty ? catDisplay : 'Uncategorized',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: catColor,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    final desc = _translator.signDescription(widget.sign);
    if (desc.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to sign',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingStatus() {
    if (widget.sign.id == null) return const SizedBox.shrink();
    final color = _isTrained ? Colors.green : Colors.orange;
    final label = _isTrained ? 'Trained' : 'Not trained';
    final subtitle = _isTrained
        ? '$_refCount reference samples available'
        : '$_sampleCount samples recorded';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _isTrained ? Icons.check_circle : Icons.sync,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final trained = _isTrained;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: trained
            ? widget.onPractice
            : () async {
                if (widget.sign.id == null) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignRecorderScreen(
                      initialSignId: widget.sign.id,
                    ),
                  ),
                );
                if (mounted) _loadTrainingInfo();
              },
        icon: Icon(trained ? Icons.videocam : Icons.fitness_center),
        label: Text(trained ? 'Practice This Sign' : 'Train This Sign'),
      ),
    );
  }
}

class _PlayPauseOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const _PlayPauseOverlay({required this.controller});

  @override
  State<_PlayPauseOverlay> createState() => _PlayPauseOverlayState();
}

class _PlayPauseOverlayState extends State<_PlayPauseOverlay> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
      _startHideTimer();
    }
    setState(() => _showControls = true);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls && widget.controller.value.isPlaying) {
          _startHideTimer();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_showControls) Container(color: Colors.black26),
          if (_showControls)
            IconButton(
              icon: Icon(
                widget.controller.value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
                size: 64,
                color: Colors.white,
              ),
              onPressed: _togglePlayPause,
            ),
          if (_showControls)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  widget.controller.value.isPlaying ? 'Playing' : 'Paused',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
