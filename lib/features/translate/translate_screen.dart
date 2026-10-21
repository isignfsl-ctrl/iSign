import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/themes/app_colors.dart';
import '../../ai/mediapipe_handler.dart';
import '../../ai/tflite_classifier.dart';
import '../../ai/gesture_sequence.dart';
import '../../ai/movement_detector.dart';
import '../../ai/classification_result.dart';
import '../../ai/reference_matcher.dart';
import '../../shared/services/tts_service.dart';
import '../../shared/services/stt_service.dart';
import '../../shared/services/app_settings.dart';
import '../../shared/services/sign_translator.dart';
import '../../shared/widgets/permission_required_screen.dart';
import '../../data/models/fsl_sign_model.dart';
import '../../data/repositories/translation_repository.dart';
import '../../data/models/translation_model.dart';
import '../../data/models/translation_detail_model.dart';
import '../../data/database/db_helper.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  TranslateScreenState createState() => TranslateScreenState();
}

class TranslateScreenState extends State<TranslateScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  String _debugLog = '';

  final _mediaPipe = MediaPipeHandler();
  final _classifier = TfliteClassifier();
  final _gestureSequence = GestureSequence();
  final _refMatcher = ReferenceMatcher();
  final _ttsService = TtsService();
  final _sttService = SttService();
  final _settings = AppSettings();
  final _translator = SignTranslator();
  final _translationRepo = TranslationRepository();
  final Map<String, String> _signNameMap = {};

  List<List<LandmarkPoint>> _currentLandmarks = [];
  String _currentLabel = '';
  double _currentConfidence = 0.0;
  String _translatedText = '';
  String _lastSavedText = '';

  bool _isSpeechMode = false;
  String _sttPartialText = '';
  String _sttErrorReason = '';
  String _sttStatusMessage = '';
  bool _isPressingToTalk = false;
  final List<String> _speechSentences = [];
  bool _sttPermissionChecked = false;
  List<String> _alternativeSigns = [];
  Timer? _altTimer;
  bool _handDetected = false;
  int _noHandFrames = 0;
  List<List<LandmarkPoint>> _lastGoodLandmarks = [];
  int _cameraSensorOrientation = 90;
  bool _isFrontCamera = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAi().catchError((_) {});
    _initTts().catchError((_) {});
    _initStt();
    _checkCameraPermission().catchError((_) {});
  }

  Future<void> _initAi() async {
    await _mediaPipe.load();
    await _classifier.load();
    await _refMatcher.load();
    await _loadSignMap();
  }

  Future<void> _loadSignMap() async {
    try {
      final db = await DbHelper().database;
      final rows = await db.query('fsl_signs');
      for (final row in rows) {
        final sign = FslSignModel.fromMap(row);
        _signNameMap[sign.signName] = sign.signNameEn ?? sign.signName;
      }
    } catch (_) {}
  }

  Future<void> _initTts() async {
    await _ttsService.init();
  }

  Future<void> _initStt() async {
    try {
      await _sttService.init();
    } catch (e) {
      debugPrint('STT init error: $e');
    }
  }

  Future<bool> _checkMicPermission() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && mounted) {
      await _showPermissionScreen(Permission.microphone);
      status = await Permission.microphone.status;
      if (status.isGranted) return true;
    }
    return false;
  }

  Future<void> _checkCameraPermission() async {
    var status = await Permission.camera.request();
    if (status.isGranted && mounted) {
      _initCamera();
    } else if (status.isPermanentlyDenied && mounted) {
      await _showPermissionScreen(Permission.camera);
      status = await Permission.camera.status;
      if (status.isGranted && mounted) {
        _initCamera();
      }
    }
  }

  Future<void> _showPermissionScreen(Permission permission) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
      builder: (_) => PermissionRequiredScreen(
        title: permission == Permission.camera
            ? 'Camera Permission Required'
            : permission == Permission.microphone
                ? 'Microphone Permission Required'
                : 'Storage Permission Required',
        message: permission == Permission.camera
            ? 'iSign needs camera access to recognize and translate '
                'Filipino Sign Language gestures in real time.'
            : permission == Permission.microphone
                ? 'iSign needs microphone access to convert your speech to text.'
                : 'iSign needs storage access to save and share '
                    'your translation recordings and transcripts.',
        icon: permission == Permission.camera
            ? Icons.videocam
            : permission == Permission.microphone
                ? Icons.mic
                : Icons.storage,
          permission: permission,
        ),
      ),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      if (_cameras!.length < 2 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only one camera detected — camera switch unavailable'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      _selectedCameraIndex = 0;
      _cameraSensorOrientation = _cameras![_selectedCameraIndex].sensorOrientation;
      _isFrontCamera = _cameras![_selectedCameraIndex].lensDirection == CameraLensDirection.front;
      await _initCameraController(_cameras![_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    _cameraController?.dispose();

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onImageStream);

      _startProcessing();

      // Load temporal classifier in background
      _classifier.loadTemporal();

      if (!mounted) return;
      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera controller error: $e');
    }
  }

  // Frame throttling: process every 3rd frame (~10fps at 30fps stream)
  int _frameSkip = 0;
  bool _processing = false;

  void _onImageStream(CameraImage image) {
    if (!_isActive || _processing) return;

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
      final landmarks = await _mediaPipe.extractLandmarks(image, _cameras![_selectedCameraIndex]);

      if (!mounted) return;

      if (landmarks.isNotEmpty && landmarks[0].length >= 21) {
        var result0 = _classifier.classifyFused(landmarks[0]);

        // Trained reference matching takes priority: approved recordings of
        // this sign are ground truth and beat the static heuristics/NN.
        // Order: DTW sequence match → single-frame match → fused classifier.
        if (_refMatcher.isLoaded) {
          final normalized = _classifier.normalizeLandmarks(landmarks[0]);
          final refResult = await _refMatcher.match(normalized);

          ClassificationResult? seqResult;
          final buffer = _classifier.landmarkBuffer;
          if (buffer.isFull) {
            final window = buffer.getWindow();
            if (window.length >= 5) {
              seqResult = await _refMatcher.matchSequence(window);
            }
          }

          if (seqResult != null) {
            result0 = seqResult;
          } else if (refResult != null) {
            result0 = refResult;
          }
        }

        final ext = _classifier.getFingerExtensions(landmarks[0]);
        final vel = _classifier.landmarkBuffer.velocity();
        final movement = _classifier.currentMovement;
        final alternatives = _classifier.currentAlternatives;

        _gestureSequence.update(result0, velocity: vel);

        String secondaryLabel = '';
        if (landmarks.length > 1 && landmarks[1].length >= 21) {
          final result1 = _classifier.classifyFused(landmarks[1]);
          secondaryLabel = '${result1.label} ${(result1.confidence * 100).toStringAsFixed(0)}%';
        }

        if (alternatives.isNotEmpty) {
          _alternativeSigns = alternatives;
          _altTimer?.cancel();
          _altTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _alternativeSigns.clear());
          });
        }

        _noHandFrames = 0;
        final transformed = _transformLandmarks(landmarks);
        _lastGoodLandmarks = transformed;
        _currentLandmarks = transformed;

        setState(() {
          _handDetected = true;
          _currentLabel = _gestureSequence.currentLabel;
          _currentConfidence = _gestureSequence.currentConfidence;
          _translatedText = _gestureSequence.translatedText;
          final extStr = ext.map((e) => e.toStringAsFixed(2)).join(' ');
          final movStr = movement.name;
          final wrist = transformed[0][0];
          _debugLog = '${result0.label} ${(result0.confidence * 100).toStringAsFixed(0)}% | '
              'vel:${(vel * 1000).toStringAsFixed(1)} '
              'mov:$movStr '
              'temp:${(_classifier.temporalConfidence * 100).toStringAsFixed(0)}% | $extStr\n'
              'wrist: ${wrist.x.toStringAsFixed(3)},${wrist.y.toStringAsFixed(3)} '
              'hands:${transformed.length} lm:${transformed[0].length}'
              '${secondaryLabel.isNotEmpty ? ' | 2nd: $secondaryLabel' : ''}';
        });
        _autoSave();
      } else {
        _noHandFrames++;
        if (_noHandFrames > 5) {
          _handDetected = false;
          _lastGoodLandmarks = [];
        }
        setState(() {
          _currentLandmarks = _lastGoodLandmarks;
          _currentLabel = '';
          _currentConfidence = 0.0;
          final loaded = _mediaPipe.isLoaded ? 'Y' : 'N';
          _debugLog = 'No hand($loaded)';
        });
      }
    } catch (_) {
    } finally {
      _processing = false;
    }
  }

  List<List<LandmarkPoint>> _transformLandmarks(List<List<LandmarkPoint>> landmarks) {
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

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only one camera available on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isCameraReady = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _cameraSensorOrientation = _cameras![_selectedCameraIndex].sensorOrientation;
    _isFrontCamera = _cameras![_selectedCameraIndex].lensDirection == CameraLensDirection.front;
    _initCameraController(_cameras![_selectedCameraIndex]);
  }

  Future<void> _speak() async {
    if (_translatedText.isEmpty) return;
    await _ttsService.setSpeed(_settings.ttsSpeed.value);
    await _ttsService.setLanguage(_settings.language.value);
    await _ttsService.speak(_translateSentence(_translatedText));
  }

  Future<void> _onPressStart() async {
    if (_isPressingToTalk) return;

    if (!_sttPermissionChecked) {
      final granted = await _checkMicPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _sttErrorReason = 'Microphone permission is required for speech-to-text';
          });
        }
        return;
      }
      _sttPermissionChecked = true;
    }

    if (!_sttService.isAvailable) {
      await _sttService.init();
    }

    if (!_sttService.isAvailable) {
      if (mounted) {
        setState(() {
          _sttErrorReason = 'Speech recognition model not loaded. Try restarting the app.';
        });
      }
      return;
    }

    _sttErrorReason = '';
    _sttStatusMessage = '';
    setState(() => _isPressingToTalk = true);

    _sttService.listen(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _sttPartialText = text);
      },
    );
  }

  Future<void> _onPressEnd() async {
    if (!_isPressingToTalk) return;
    final finalText = await _sttService.stop();
    if (mounted) {
      setState(() {
        _isPressingToTalk = false;
        _sttPartialText = '';
        if (finalText.trim().isNotEmpty) {
          _speechSentences.add(finalText.trim());
          _translatedText = _speechSentences.join(' ');
        } else {
          _sttStatusMessage = 'No speech detected — check mic and try speaking clearly';
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _sttStatusMessage = '');
          });
        }
      });
      _autoSave();
    }
  }

  void _clearConversation() {
    setState(() {
      _speechSentences.clear();
      _translatedText = '';
      _lastSavedText = '';
      _sttStatusMessage = '';
    });
  }

  Future<void> _saveTranslation() async {
    String text = _translatedText;
    if (text.isEmpty && _currentConfidence >= 0.75) {
      text = _currentLabel;
    }
    if (text.isEmpty) return;
    final id = await _translationRepo.insertTranslation(TranslationModel(
      mode: _isSpeechMode ? 'speech' : 'realtime',
      outputLanguage: _settings.language.value,
    ));
    final words = text.split(' ');
    for (int i = 0; i < words.length; i++) {
      await _translationRepo.insertDetail(TranslationDetailModel(
        translationId: id,
        signId: null,
        sequenceOrder: i,
        translatedText: words[i],
        confidenceScore: 1.0,
      ));
    }
  }

  void _autoSave() {
    if (_translatedText.isNotEmpty && _translatedText != _lastSavedText) {
      _lastSavedText = _translatedText;
      _saveTranslation();
    }
  }

  void _switchToSpeechMode() {
    setState(() {
      _isSpeechMode = true;
      if (!_sttService.isAvailable) {
        _sttErrorReason = 'Speech recognition model not loaded. Try restarting the app.';
      } else {
        _sttErrorReason = '';
      }
    });
  }

  Future<void> _shareTranscript() async {
    if (_translatedText.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/transcript_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(_translatedText);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  String _translateLabel(String label) {
    if (!_translator.isEnglish || label.isEmpty) return label;
    return _signNameMap[label] ?? label;
  }

  String _translateSentence(String text) {
    if (!_translator.isEnglish || text.isEmpty) return text;
    return text.split(' ').map((w) => _signNameMap[w] ?? w).join(' ');
  }

  void stopCamera() {
    _isActive = false;
    _cameraController?.stopImageStream();
  }

  void startCamera() {
    _isActive = true;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.startImageStream(_onImageStream);
      _startProcessing();
    } else {
      _checkCameraPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopCamera();
    _cameraController?.dispose();
    _mediaPipe.dispose();
    _classifier.dispose();
    _ttsService.dispose();
    _sttService.dispose();
    _altTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isActive) startCamera();
    } else if (state == AppLifecycleState.hidden) {
      stopCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isSpeechMode) _buildSpeechModeUi() else _buildCameraPreview(),
          if (!_isSpeechMode) _buildMovementBadge(),
          if (!_isSpeechMode) _buildCameraSwitchButton(),
          _buildTopPanel(),
          _buildBottomPanel(),
          _buildHandStatusBadge(),
          _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady || _cameraController == null) {
      return Container(
        color: AppColors.darkBackground,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, size: 64, color: AppColors.disabled),
              SizedBox(height: 16),
              Text(
                'Camera not available',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(
            _cameraController!,
            child: _buildHandSkeletonContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildHandSkeletonContent() {
    return CustomPaint(
      painter: _HandSkeletonPainter(
        landmarks: _currentLandmarks,
        handDetected: _handDetected,
      ),
    );
  }

  Widget _buildCameraSwitchButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 12,
      child: GestureDetector(
        onTap: _toggleCamera,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.flip_camera_android,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildHandStatusBadge() {
    final handCount = _handDetected ? _currentLandmarks.length : 0;
    final h1 = _handDetected ? _mediaPipe.lastHandedness : '';
    final h2 = _handDetected && handCount >= 2 ? _mediaPipe.lastHandedness2 : '';
    return Positioned(
      top: MediaQuery.of(context).padding.top + 110,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _handDetected ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: _handDetected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              _handDetected
                  ? '$handCount hand${handCount > 1 ? 's' : ''}'
                      '${h1.isNotEmpty ? ' ($h1' : ''}'
                      '${h2.isNotEmpty ? ', $h2' : ''}'
                      '${h1.isNotEmpty ? ')' : ''}'
                  : 'Searching...',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugOverlay() {
    if (_isSpeechMode) return const SizedBox.shrink();

    final cameraCount = _cameras?.length ?? 0;
    final handCount = _handDetected ? _currentLandmarks.length : 0;
    final handStatus = _handDetected ? 'HAND OK x$handCount' : 'NO HAND';
    final h1 = _handDetected ? _mediaPipe.lastHandedness : '';
    final h2 = _handDetected && handCount >= 2 ? _mediaPipe.lastHandedness2 : '';
    final hStr = h1.isNotEmpty ? ' $h1${h2.isNotEmpty ? ', $h2' : ''}' : '';

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 60,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'cam:$cameraCount | $handStatus$hStr',
              style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: 'monospace'),
            ),
            if (_debugLog.isNotEmpty)
              Text(
                _debugLog,
                style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementBadge() {
    final movement = _classifier.currentMovement;
    if (movement == MovementType.still || movement == MovementType.unknown) {
      return const SizedBox.shrink();
    }

    final (icon, label) = switch (movement) {
      MovementType.wave     => (Icons.waves, 'Wave'),
      MovementType.forward  => (Icons.arrow_forward, 'Forward'),
      MovementType.circular => (Icons.autorenew, 'Circular'),
      MovementType.up       => (Icons.arrow_upward, 'Up'),
      MovementType.down     => (Icons.arrow_downward, 'Down'),
      MovementType.left     => (Icons.arrow_back, 'Left'),
      MovementType.right    => (Icons.arrow_forward, 'Right'),
      _                     => (Icons.question_mark, '?'),
    };

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechModeUi() {
    final topInset = MediaQuery.of(context).padding.top + 56;
    return Container(
      color: AppColors.darkBackground,
      child: !_sttService.isAvailable
          ? _buildSttUnavailableUi(topInset)
          : _buildSttAvailableUi(topInset),
    );
  }

  Widget _buildSttUnavailableUi(double topInset) {
    return Column(
      children: [
        SizedBox(height: topInset + 40),
        const Icon(Icons.mic_off, size: 72, color: Colors.white24),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _sttErrorReason.isNotEmpty
                ? _sttErrorReason
                : 'Speech recognition is not available',
            style: const TextStyle(fontSize: 16, color: Colors.orangeAccent),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Vosk offline speech recognition engine is bundled with the app',
            style: TextStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSttAvailableUi(double topInset) {
    final botInset = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        SizedBox(height: topInset),
        // Conversation area
        Expanded(
          child: _speechSentences.isEmpty
              ? Center(
                  child: Text(
                    _sttStatusMessage.isNotEmpty
                        ? _sttStatusMessage
                        : 'Hold the mic button below to speak',
                    style: TextStyle(
                      fontSize: 15,
                      color: _sttStatusMessage.isNotEmpty ? Colors.orangeAccent : Colors.white38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _speechSentences.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _speechSentences[i],
                              style: const TextStyle(fontSize: 17, color: Colors.white, height: 1.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        // Partial text
        if (_isPressingToTalk && _sttPartialText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _sttPartialText,
              style: const TextStyle(fontSize: 16, color: Colors.white54, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // PTT section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xF0121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Last sentence summary
              if (_speechSentences.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _speechSentences.last,
                    style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_speechSentences.isNotEmpty)
                const SizedBox(height: 12),
              // PTT button
              GestureDetector(
                onTapDown: (_) => _onPressStart(),
                onTapUp: (_) => _onPressEnd(),
                onTapCancel: () => _onPressEnd(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isPressingToTalk ? 220 : 200,
                  height: _isPressingToTalk ? 220 : 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPressingToTalk ? Colors.greenAccent : Colors.white12,
                    border: Border.all(
                      color: _isPressingToTalk ? Colors.greenAccent : Colors.white24,
                      width: _isPressingToTalk ? 4 : 2,
                    ),
                    boxShadow: _isPressingToTalk
                        ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic,
                        size: 56,
                        color: _isPressingToTalk ? Colors.black87 : Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPressingToTalk ? 'Listening...' : 'Tap & Hold',
                        style: TextStyle(
                          fontSize: _isPressingToTalk ? 15 : 13,
                          fontWeight: FontWeight.w600,
                          color: _isPressingToTalk ? Colors.black87 : Colors.white70,
                        ),
                      ),
                      if (!_isPressingToTalk)
                        Text(
                          'to Speak',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Clear + share
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_speechSentences.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearConversation,
                      icon: const Icon(Icons.clear_all, size: 18, color: Colors.white54),
                      label: const Text('Clear', style: TextStyle(fontSize: 13, color: Colors.white54)),
                    ),
                  if (_speechSentences.isNotEmpty)
                    TextButton.icon(
                      onPressed: _translatedText.isNotEmpty ? _shareTranscript : null,
                      icon: const Icon(Icons.share, size: 18, color: Colors.amber),
                      label: const Text('Share', style: TextStyle(fontSize: 13, color: Colors.amber)),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: botInset),
      ],
    );
  }

  Widget _buildTopPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: Column(
        children: [
          // Mode toggle
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _onPressEnd();
                            setState(() => _isSpeechMode = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: !_isSpeechMode ? Colors.white24 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pan_tool, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Gesture', style: TextStyle(fontSize: 13, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _switchToSpeechMode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: _isSpeechMode ? Colors.white24 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mic, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Speech', style: TextStyle(fontSize: 13, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Recognition result
          if (!_isSpeechMode) _buildGestureResult(),
          if (_alternativeSigns.isNotEmpty && !_isSpeechMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _alternativeSigns.map((sign) => GestureDetector(
                  onTap: () {
                    _gestureSequence.update(
                      ClassificationResult(label: sign, confidence: 0.85),
                      velocity: 0.0,
                    );
                    setState(() {
                      _currentLabel = sign;
                      _translatedText = _gestureSequence.translatedText;
                      _alternativeSigns.clear();
                    });
                    _altTimer?.cancel();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      sign,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                )).toList(),
              ),
            ),
          if (_currentLabel.isEmpty && !_isSpeechMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Show your hand to the camera',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGestureResult() {
    if (_currentLabel.isNotEmpty && _currentConfidence >= 0.75) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _translateLabel(_currentLabel),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _currentConfidence,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _currentConfidence >= 0.9
                      ? Colors.green
                      : AppColors.accentLight,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_currentConfidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      );
    } else if (_currentLabel.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Sign not recognized',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.orangeAccent,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomPanel() {
    if (_isSpeechMode) {
      return const SizedBox.shrink();
    }

    final hasTranslation = _translatedText.isNotEmpty;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: hasTranslation
          ? Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomPadding + 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xF0121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _translateSentence(_translatedText),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _iconButton(
                        icon: Icons.volume_up,
                        label: 'Speak',
                        color: AppColors.accentLight,
                        onPressed: _speak,
                      ),
                      _iconButton(
                        icon: Icons.share,
                        label: 'Share',
                        color: Colors.amber,
                        onPressed: _shareTranscript,
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding + 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconButton(
                    icon: Icons.volume_up,
                    label: 'Speak',
                    color: AppColors.accentLight,
                    onPressed: null,
                  ),
                  _iconButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.amber,
                    onPressed: null,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: onPressed != null ? color : Colors.grey),
          onPressed: onPressed,
          iconSize: 32,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? Colors.white70 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _HandSkeletonPainter extends CustomPainter {
  final List<List<LandmarkPoint>> landmarks;
  final bool handDetected;

  _HandSkeletonPainter({required this.landmarks, required this.handDetected});

  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [5, 9], [9, 10], [10, 11], [11, 12],
    [9, 13], [13, 14], [14, 15], [15, 16],
    [13, 17], [17, 18], [18, 19], [19, 20],
    [0, 17],
  ];

  static const _fingerTips = [4, 8, 12, 16, 20];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    for (int h = 0; h < landmarks.length; h++) {
      final hand = landmarks[h];
      if (hand.length < 21) continue;

      final isPrimary = h == 0;
      final hue = isPrimary ? 120.0 : 210.0;
      final color = HSLColor.fromAHSL(0.9, hue, 1.0, 0.5).toColor();

      final bonePaint = Paint()
        ..color = color
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      final jointPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final tipPaint = Paint()
        ..color = isPrimary ? Colors.yellowAccent : Colors.cyanAccent
        ..style = PaintingStyle.fill;

      final wristPaint = Paint()
        ..color = isPrimary ? Colors.redAccent : Colors.orangeAccent
        ..style = PaintingStyle.fill;

      for (final conn in _connections) {
        if (conn[0] < hand.length && conn[1] < hand.length) {
          final p1 = Offset(hand[conn[0]].x * size.width, hand[conn[0]].y * size.height);
          final p2 = Offset(hand[conn[1]].x * size.width, hand[conn[1]].y * size.height);
          canvas.drawLine(p1, p2, bonePaint);
        }
      }

      final wristPos = Offset(hand[0].x * size.width, hand[0].y * size.height);
      canvas.drawCircle(wristPos, 12, wristPaint);

      for (int i = 1; i < 21; i++) {
        final pos = Offset(hand[i].x * size.width, hand[i].y * size.height);
        canvas.drawCircle(pos, 6, jointPaint);
      }

      for (final tipIdx in _fingerTips) {
        if (tipIdx < hand.length) {
          final pos = Offset(hand[tipIdx].x * size.width, hand[tipIdx].y * size.height);
          canvas.drawCircle(pos, 9, tipPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HandSkeletonPainter oldDelegate) => true;
}
