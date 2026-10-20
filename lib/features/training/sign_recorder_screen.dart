import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/themes/app_colors.dart';
import '../../ai/mediapipe_handler.dart';
import '../../ai/tflite_classifier.dart';
import '../../data/database/db_helper.dart';
import '../../data/repositories/training_repository.dart';
import '../../shared/widgets/permission_required_screen.dart';
import '../../shared/services/app_settings.dart';
import 'package:isign_shared/isign_shared.dart';

class SignRecorderScreen extends StatefulWidget {
  final int? initialSignId;
  const SignRecorderScreen({super.key, this.initialSignId});

  @override
  State<SignRecorderScreen> createState() => _SignRecorderScreenState();
}

enum RecorderMode { burst, continuous }

class _SignRecorderScreenState extends State<SignRecorderScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  int _cameraIndex = 0;

  final _mediaPipe = MediaPipeHandler();
  final _classifier = TfliteClassifier();
  final _repo = TrainingRepository();

  List<List<LandmarkPoint>> _currentLandmarks = [];
  List<Map<String, dynamic>> _signs = [];
  int? _selectedSignId;
  String _selectedSignDescription = '';
  String _selectedSignName = '';
  int _sampleCount = 0;
  int _totalSamples = 0;
  bool _isSaving = false;

  // Classification feedback
  String _recognizedLabel = '';
  double _recognizedConfidence = 0.0;

  // Camera orientation
  int _cameraSensorOrientation = 90;
  bool _isFrontCamera = false;

  // Burst recording
  bool _isBursting = false;
  int _burstProgress = 0;
  final List<Map<String, dynamic>> _burstFrames = [];
  static const int _burstTarget = 30;

  // Continuous recording
  RecorderMode _recorderMode = RecorderMode.burst;
  bool _isRecordingContinuous = false;
  final List<Map<String, dynamic>> _continuousFrames = [];
  DateTime? _continuousStartedAt;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _mediaPipe.load();
    await _classifier.load();
    await _loadSigns();
    if (widget.initialSignId != null && mounted) {
      final found =
          _signs.where((s) => s['id'] == widget.initialSignId).toList();
      if (found.isNotEmpty) {
        setState(() {
          _selectedSignId = widget.initialSignId;
          _selectedSignDescription =
              (found.first['description'] as String?) ?? '';
          _selectedSignName = (found.first['sign_name'] as String?) ?? '';
        });
        _loadSampleCount();
      }
    }
    await _loadCounts();
    _checkCameraPermission().catchError((_) {});
  }

  Future<void> _loadSigns() async {
    final db = await DbHelper().database;
    final signs = await db.query('fsl_signs', orderBy: 'sign_name ASC');
    if (!mounted) return;
    setState(() => _signs = signs);
  }

  Future<void> _loadCounts() async {
    final total = await _repo.getTotalCount();
    if (!mounted) return;
    setState(() => _totalSamples = total);
  }

  Future<void> _loadSampleCount() async {
    if (_selectedSignId == null) {
      setState(() => _sampleCount = 0);
      return;
    }
    final samples = await _repo.getSamplesBySign(_selectedSignId!);
    if (!mounted) return;
    setState(() => _sampleCount = samples.length);
  }

  Future<void> _checkCameraPermission() async {
    var status = await Permission.camera.request();
    if (status.isGranted && mounted) {
      _initCamera();
    } else if (status.isPermanentlyDenied && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PermissionRequiredScreen(
            title: 'Camera Permission Required',
            message:
                'Sign Recorder needs camera access to capture hand landmarks for training.',
            icon: Icons.videocam,
            permission: Permission.camera,
          ),
        ),
      );
      status = await Permission.camera.status;
      if (status.isGranted && mounted) _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _cameraController?.dispose();
      _cameraSensorOrientation = _cameras![_cameraIndex].sensorOrientation;
      _isFrontCamera =
          _cameras![_cameraIndex].lensDirection == CameraLensDirection.front;
      _cameraController = CameraController(
        _cameras![_cameraIndex],
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onImageStream);
      _startProcessing();

      if (!mounted) return;
      setState(() => _isCameraReady = true);
    } catch (_) {}
  }

  // Frame throttling: process every 3rd frame (~10fps at 30fps stream)
  int _frameSkip = 0;
  bool _processing = false;

  void _onImageStream(CameraImage image) {
    if (_processing) return;
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;
    _processing = true;
    _processFrame(image);
  }

  void _startProcessing() {
    // No timer needed — processing runs in stream callback via background isolate
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final landmarks = await _mediaPipe.extractLandmarks(
          image, _cameraController!.description);

      String label = '';
      double confidence = 0.0;
      if (landmarks.isNotEmpty && landmarks[0].length >= 21) {
        final result = _classifier.classifyFused(landmarks[0]);
        label = result.label;
        confidence = result.confidence;
      }

      final transformed = _transformLandmarks(landmarks);

      if (mounted) {
        setState(() {
          _currentLandmarks = transformed;
          _recognizedLabel = label;
          _recognizedConfidence = confidence;
        });
      }

      if (landmarks.isEmpty) return;

      for (int h = 0; h < landmarks.length; h++) {
        final pts = landmarks[h];
        if (pts.length < 21) continue;

        final frame = <double>[];
        for (final pt in pts) {
          frame.addAll([pt.x, pt.y, pt.z]);
        }

        final handedness =
            (h == 0) ? _mediaPipe.lastHandedness : _mediaPipe.lastHandedness2;
        if (handedness.isEmpty) continue;

        if (_isBursting) {
          _burstFrames
              .add({'frame': frame, 'handedness': handedness, 'handIdx': h});
          final progress = _burstFrames.length;
          if (mounted) {
            setState(() => _burstProgress = progress);
          }
          if (progress >= _burstTarget) {
            _saveBurst();
          }
        }

        if (_isRecordingContinuous) {
          _continuousFrames
              .add({'frame': frame, 'handedness': handedness, 'handIdx': h});
        }
      }
    } catch (_) {
    } finally {
      _processing = false;
    }
  }

  List<List<LandmarkPoint>> _transformLandmarks(
      List<List<LandmarkPoint>> landmarks) {
    return landmarks.map((hand) {
      return hand.map((pt) {
        double x = pt.x;
        double y = pt.y;
        switch (_cameraSensorOrientation) {
          case 90:
            x = 1.0 - pt.y;
            y = pt.x;
            break;
          case 270:
            x = pt.y;
            y = 1.0 - pt.x;
            break;
          case 180:
            x = 1.0 - pt.x;
            y = 1.0 - pt.y;
            break;
        }
        if (_isFrontCamera) {
          x = 1.0 - x;
        }
        return LandmarkPoint(x, y, pt.z, pt.wx, pt.wy, pt.wz);
      }).toList();
    }).toList();
  }

  // --- Burst mode ---

  Future<void> _captureSample() async {
    if (_selectedSignId == null) return;
    if (_isBursting) return;
    _burstFrames.clear();
    setState(() {
      _isBursting = true;
      _burstProgress = 0;
    });
  }

  Future<void> _saveBurst() async {
    if (_burstFrames.length < _burstTarget) return;
    setState(() => _isSaving = true);

    final data = <double>[];
    String? savedHandedness;
    int? savedHandIdx;
    for (final item in _burstFrames) {
      data.addAll(item['frame'] as List<double>);
      if (savedHandedness == null) {
        savedHandedness = item['handedness'] as String?;
        savedHandIdx = item['handIdx'] as int?;
      }
    }

    final userName = AppSettings().userName.value.isNotEmpty
        ? AppSettings().userName.value
        : null;

    await _repo.insertSample(TrainingSample(
      signId: _selectedSignId!,
      landmarks: data,
      handedness: savedHandedness ?? 'unknown',
      handIdx: savedHandIdx ?? 0,
      userName: userName,
    ));

    setState(() {
      _isBursting = false;
      _burstProgress = 0;
      _isSaving = false;
    });
    _burstFrames.clear();
    await _loadSampleCount();
    await _loadCounts();
  }

  // --- Continuous mode (NEW) ---

  Future<void> _startContinuous() async {
    if (_selectedSignId == null) return;
    _continuousFrames.clear();
    setState(() {
      _isRecordingContinuous = true;
      _continuousStartedAt = DateTime.now();
    });
  }

  Future<void> _stopContinuous() async {
    if (!_isRecordingContinuous) return;
    setState(() => _isRecordingContinuous = false);

    if (_continuousFrames.length < _burstTarget) {
      _continuousFrames.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Too few frames recorded — need at least 30')),
        );
      }
      return;
    }

    final segments = _segmentFrames(_continuousFrames);
    _continuousFrames.clear();

    if (segments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No clear sign segments found — try pausing between signs')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    int saved = 0;
    for (final seg in segments) {
      final data = <double>[];
      String? savedHandedness;
      int? savedHandIdx;
      for (final item in seg) {
        data.addAll(item['frame'] as List<double>);
        if (savedHandedness == null) {
          savedHandedness = item['handedness'] as String?;
          savedHandIdx = item['handIdx'] as int?;
        }
      }
      await _repo.insertSample(TrainingSample(
        userName: AppSettings().userName.value.isNotEmpty
            ? AppSettings().userName.value
            : null,
        signId: _selectedSignId!,
        landmarks: data,
        handedness: savedHandedness ?? 'unknown',
        handIdx: savedHandIdx ?? 0,
      ));
      saved++;
    }

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $saved sign segments from recording')),
      );
    }

    await _loadSampleCount();
    await _loadCounts();
  }

  List<List<Map<String, dynamic>>> _segmentFrames(
      List<Map<String, dynamic>> frames) {
    if (frames.length < _burstTarget) return [];

    // Extract just the frame data for velocity calculation
    final frameData = frames.map((f) => f['frame'] as List<double>).toList();

    // Compute velocity between consecutive frames
    final velocities = <double>[];
    for (int i = 1; i < frameData.length; i++) {
      double sum = 0.0;
      for (int j = 0;
          j < min(frameData[i].length, frameData[i - 1].length);
          j++) {
        final d = frameData[i][j] - frameData[i - 1][j];
        sum += d * d;
      }
      velocities
          .add(sqrt(sum / min(frameData[i].length, frameData[i - 1].length)));
    }

    // Find low-velocity regions (sign boundaries)
    const velThreshold = 0.008;
    const minBoundaryFrames = 5;
    const minSegmentFrames = 15;
    const maxSegmentFrames = 60;

    final boundaries = <int>[0]; // always start at frame 0
    int lowVelCount = 0;

    for (int i = 0; i < velocities.length; i++) {
      if (velocities[i] < velThreshold) {
        lowVelCount++;
        if (lowVelCount >= minBoundaryFrames && boundaries.last < i + 1) {
          if (!boundaries.contains(i + 1)) {
            boundaries.add(i + 1);
          }
          lowVelCount = 0;
        }
      } else {
        lowVelCount = 0;
      }
    }
    boundaries.add(frames.length); // always end at last frame

    // Build segments from boundary ranges
    final segments = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < boundaries.length - 1; i++) {
      final start = boundaries[i];
      final end = boundaries[i + 1];
      final length = end - start;
      if (length >= minSegmentFrames) {
        final seg = frames.sublist(start, end);
        // Truncate to maxSegmentFrames
        if (seg.length > maxSegmentFrames) {
          segments.add(seg.sublist(0, maxSegmentFrames));
        } else {
          segments.add(seg);
        }
      }
    }

    return segments;
  }

  // --- Shared ---

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    setState(() {
      _cameraIndex = _cameraIndex == 0 ? 1 : 0;
      _isCameraReady = false;
    });
    _initCamera();
  }

  Future<void> _exportData() async {
    final csv = await _repo.exportAsCsv(temporal: true);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/fsl_temporal_data_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'FSL Training Data',
    ));
  }

  Future<void> _showHelpDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How to Use Sign Recorder'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('1. Select an FSL sign from the dropdown.',
                  style: TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 4),
              const Text(
                  '2. Read the tip below the dropdown to learn how to form the sign.',
                  style: TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 4),
              const Text('3. Position your hand clearly in the camera frame.',
                  style: TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Burst mode',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 4),
              const Text(
                  'Captures 30 frames in one quick burst. Best for static signs like numbers, letters, or held handshapes. Hold your hand still while it captures.',
                  style: TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 12),
              Text('Continuous mode',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 4),
              const Text(
                  'Records continuously until you press Stop. The app then auto-segments the recording into individual sign clips. Best for movement-based signs or practicing multiple repetitions in one take.',
                  style: TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  bool get _hasUnfinishedRecording =>
      (_isBursting && _burstFrames.isNotEmpty) || _isRecordingContinuous;

  Future<void> _confirmDiscardOnBack() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard recording?'),
        content: Text(
          _isRecordingContinuous
              ? 'You are still recording. The ${_continuousFrames.length} frames recorded so far will be discarded.'
              : 'This sample is incomplete (${_burstFrames.length}/$_burstTarget frames) and will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() {
      _isBursting = false;
      _burstProgress = 0;
      _isRecordingContinuous = false;
      _burstFrames.clear();
      _continuousFrames.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _mediaPipe.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnfinishedRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isSaving) return;
        if (_hasUnfinishedRecording) _confirmDiscardOnBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sign Recorder'),
          actions: [
            if (_selectedSignId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Chip(
                  label: Text(_selectedSignName,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white)),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'How to use Sign Recorder',
              onPressed: _showHelpDialog,
            ),
            IconButton(
              icon: Icon(
                  _cameraIndex == 0 ? Icons.camera_front : Icons.camera_rear),
              tooltip: 'Switch camera',
              onPressed: _switchCamera,
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Export training data',
              onPressed: _exportData,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isCameraReady && _cameraController != null
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize!.height,
                          height: _cameraController!.value.previewSize!.width,
                          child: Stack(
                            children: [
                              CameraPreview(_cameraController!),
                              CustomPaint(
                                size: Size.infinite,
                                painter: _LandmarkPainter(
                                    landmarks: _currentLandmarks),
                              ),
                              _buildClassificationOverlay(),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.darkBackground,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationOverlay() {
    if (_recognizedLabel.isEmpty) return const SizedBox.shrink();

    final isMatching = _selectedSignName.isNotEmpty &&
        _recognizedLabel.toLowerCase() == _selectedSignName.toLowerCase();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recognizedLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (_selectedSignName.isNotEmpty)
                      Text(
                        'Selected: $_selectedSignName',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54),
                      ),
                  ],
                ),
                Icon(
                  isMatching ? Icons.check_circle : Icons.cancel,
                  color: isMatching ? Colors.green : Colors.orange,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _recognizedConfidence,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _recognizedConfidence >= 0.9
                      ? Colors.green
                      : _recognizedConfidence >= 0.6
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(_recognizedConfidence * 100).toStringAsFixed(0)}% confidence',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xF0121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedSignId,
            decoration: InputDecoration(
              labelText: 'Select FSL Sign',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white12,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            items: _signs
                .map((s) => DropdownMenuItem(
                      value: s['id'] as int,
                      child: Text(s['sign_name'] as String),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedSignId = v;
                final s = _signs.firstWhere((s) => s['id'] == v,
                    orElse: () => <String, dynamic>{});
                _selectedSignDescription = (s['description'] as String?) ?? '';
                _selectedSignName = (s['sign_name'] as String?) ?? '';
              });
              _loadSampleCount();
            },
          ),
          const SizedBox(height: 8),
          // Sign description tip
          if (_selectedSignId != null && _selectedSignDescription.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.accentLight, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedSignDescription,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedSignId != null && _selectedSignDescription.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('No description available for this sign.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
            ),
          if (_selectedSignId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_upward, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Text('Select a sign above to begin training',
                      style: TextStyle(color: Colors.amber, fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Mode toggle
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                    RecorderMode.burst, 'Burst', Icons.burst_mode),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(RecorderMode.continuous, 'Continuous',
                    Icons.radio_button_checked),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Mode description
          Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                _recorderMode == RecorderMode.burst
                    ? Icons.flash_on
                    : Icons.videocam,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                _recorderMode == RecorderMode.burst
                    ? 'Quick 30-frame burst — hold your hand still'
                    : 'Record freely — press Stop to save segments',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Record button
          _buildRecordButton(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Samples for this sign: $_sampleCount',
                  style: const TextStyle(color: Colors.white70)),
              Text('Total samples: $_totalSamples',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _selectedSignId == null
                  ? 'Select an FSL sign from the dropdown first'
                  : _currentLandmarks.isEmpty
                      ? 'Show your hand to the camera — no hand detected'
                      : _isBursting
                          ? 'Capturing burst... keep your hand visible'
                          : _isRecordingContinuous
                              ? 'Recording... perform signs then press Stop'
                              : '${_currentLandmarks[0].length} landmarks detected — ready to record',
              style: TextStyle(
                color: _selectedSignId == null
                    ? Colors.amber
                    : _currentLandmarks.isEmpty
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(RecorderMode mode, String label, IconData icon) {
    final isActive = _recorderMode == mode;
    return OutlinedButton.icon(
      onPressed:
          (_selectedSignId != null && !_isRecordingContinuous && !_isBursting)
              ? () => setState(() => _recorderMode = mode)
              : null,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isActive ? AppColors.accentLight : Colors.white54,
        backgroundColor: isActive
            ? AppColors.accentLight.withValues(alpha: 0.15)
            : Colors.white12,
        side: BorderSide(
          color: isActive ? AppColors.accentLight : Colors.white24,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildRecordButton() {
    if (_recorderMode == RecorderMode.burst) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_selectedSignId != null &&
                      !_isSaving &&
                      !_isBursting &&
                      _currentLandmarks.isNotEmpty)
                  ? _captureSample
                  : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : (_isBursting
                      ? const Icon(Icons.hourglass_top)
                      : const Icon(Icons.camera_alt)),
              label: Text(_isBursting
                  ? 'Recording $_burstProgress/$_burstTarget...'
                  : (_isSaving ? 'Saving...' : 'Record 30 frames')),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isBursting ? Colors.orange : AppColors.accentLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    // Continuous mode
    final dur = _continuousStartedAt != null
        ? DateTime.now().difference(_continuousStartedAt!)
        : Duration.zero;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isRecordingContinuous
                ? _stopContinuous
                : (_selectedSignId != null &&
                        !_isSaving &&
                        _currentLandmarks.isNotEmpty
                    ? _startContinuous
                    : null),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_isRecordingContinuous
                    ? Icons.stop
                    : Icons.fiber_manual_record),
            label: Text(
              _isSaving
                  ? 'Saving segments...'
                  : (_isRecordingContinuous
                      ? 'Stop (${dur.inSeconds}s, ${_continuousFrames.length} frames)'
                      : 'Start Recording'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecordingContinuous
                  ? Colors.red
                  : (_isSaving ? Colors.grey : Colors.green),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandmarkPainter extends CustomPainter {
  final List<List<LandmarkPoint>> landmarks;

  _LandmarkPainter({required this.landmarks});

  static const _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final hand in landmarks) {
      for (final conn in _connections) {
        if (conn[0] < hand.length && conn[1] < hand.length) {
          final p1 = Offset(
              hand[conn[0]].x * size.width, hand[conn[0]].y * size.height);
          final p2 = Offset(
              hand[conn[1]].x * size.width, hand[conn[1]].y * size.height);
          canvas.drawLine(p1, p2, paint);
        }
      }

      for (final point in hand) {
        final pos = Offset(point.x * size.width, point.y * size.height);
        canvas.drawCircle(pos, 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter oldDelegate) => true;
}
