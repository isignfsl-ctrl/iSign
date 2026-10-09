import 'dart:math';
import 'package:camera/camera.dart';
import 'package:hand_detection/hand_detection.dart';

class LandmarkPoint {
  final double x;
  final double y;
  final double z;
  final double wx;
  final double wy;
  final double wz;
  const LandmarkPoint(this.x, this.y, this.z, this.wx, this.wy, this.wz);
}

class MediaPipeHandler {
  HandDetector? _detector;
  bool _isLoaded = false;
  String? _loadError;

  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;

  // EMA smoothing
  List<List<LandmarkPoint>>? _prevLandmarks;
  static const double _emaAlpha = 0.72;
  static const double _fastAlpha = 0.9;
  static const double _velThreshold = 0.02;

  // Handedness temporal filter
  final _handHistory = <List<String>>[];
  static const int _handHistorySize = 8;
  String lastHandedness = '';
  String lastHandedness2 = '';

  Future<void> load() async {
    try {
      _detector = await HandDetector.create(
        useCompiledModel: true,
        detectorConf: 0.45,
        maxDetections: 2,
      );
      _isLoaded = true;
    } catch (e) {
      _loadError = 'HandDetector: $e';
      _isLoaded = false;
    }
  }

  Future<List<List<LandmarkPoint>>> extractLandmarks(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (!_isLoaded || _detector == null) return [];

    try {
      final hands = await _detector!.detectFromCameraImage(
        image,
        maxDim: 640,
      );

      if (hands.isEmpty) return [];

      final result = <List<LandmarkPoint>>[];

      for (final hand in hands) {
        if (!hand.hasLandmarks) continue;

        final imgW = hand.imageWidth;
        final imgH = hand.imageHeight;

        final landmarks = <LandmarkPoint>[];
        for (final lm in hand.landmarks) {
          final nx = lm.x / imgW;
          final ny = lm.y / imgH;
          landmarks.add(LandmarkPoint(nx, ny, lm.z, 0, 0, 0));
        }

        if (landmarks.length >= 21) {
          result.add(landmarks);
          if (result.length == 1) {
            lastHandedness = hand.handedness == Handedness.left ? 'Left' : 'Right';
          } else if (result.length == 2) {
            lastHandedness2 = hand.handedness == Handedness.left ? 'Left' : 'Right';
          }
        }
      }

      var smoothed = _applySmoothing(result);
      _updateHandednessHistory(result);
      return smoothed;
    } catch (e) {
      return [];
    }
  }

  List<List<LandmarkPoint>> _applySmoothing(List<List<LandmarkPoint>> current) {
    if (current.isEmpty) {
      _prevLandmarks = null;
      return current;
    }

    final smoothed = <List<LandmarkPoint>>[];
    for (int h = 0; h < current.length; h++) {
      final hand = current[h];
      List<LandmarkPoint> prevHand;
      if (_prevLandmarks != null && h < _prevLandmarks!.length &&
          _prevLandmarks![h].length == hand.length) {
        prevHand = _prevLandmarks![h];
      } else {
        prevHand = hand;
      }

      final dx = hand[0].x - prevHand[0].x;
      final dy = hand[0].y - prevHand[0].y;
      final vel = sqrt(dx * dx + dy * dy);
      final alpha = vel > _velThreshold ? _fastAlpha : _emaAlpha;

      smoothed.add(List.generate(hand.length, (i) {
        final curr = hand[i];
        final prev = prevHand[i];
        return LandmarkPoint(
          alpha * curr.x + (1 - alpha) * prev.x,
          alpha * curr.y + (1 - alpha) * prev.y,
          alpha * curr.z + (1 - alpha) * prev.z,
          0, 0, 0,
        );
      }));
    }

    _prevLandmarks = smoothed;
    return smoothed;
  }

  void _updateHandednessHistory(List<List<LandmarkPoint>> hands) {
    if (hands.isEmpty) return;

    final labels = <String>[];
    if (hands.length >= 1) labels.add(lastHandedness.isNotEmpty ? lastHandedness : 'Right');
    if (hands.length >= 2) labels.add(lastHandedness2.isNotEmpty ? lastHandedness2 : 'Left');

    _handHistory.add(labels);
    if (_handHistory.length > _handHistorySize) {
      _handHistory.removeAt(0);
    }
  }

  void dispose() {
    _detector?.dispose();
  }
}
