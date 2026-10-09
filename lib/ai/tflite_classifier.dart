import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'classification_result.dart';
import 'mediapipe_handler.dart';
import 'hand_shape_recognizer.dart';
import 'temporal_classifier.dart';
import 'landmark_buffer.dart';
import 'movement_detector.dart';
import 'gesture_dictionary.dart';

class TfliteClassifier {
  Map<String, dynamic>? _modelData;
  List<List<double>>? _w1, _w2, _w3;
  List<double>? _b1, _b2, _b3;
  List<String> _labels = [];
  bool _isLoaded = false;
  final _shapeRecognizer = HandShapeRecognizer();
  final temporalClassifier = TemporalClassifier();
  final landmarkBuffer = LandmarkBuffer(30);
  final _movementDetector = MovementDetector();
  final _gestureDictionary = GestureDictionary();
  final _labelSmoother = TemporalSmoother(windowSize: 10, threshold: 0.6);
  double _tempConfidence = 0.0;
  MovementType _currentMovement = MovementType.unknown;
  List<String> _currentAlternatives = [];

  bool get isLoaded => _isLoaded;
  double get temporalConfidence => _tempConfidence;
  MovementType get currentMovement => _currentMovement;
  List<String> get currentAlternatives => _currentAlternatives;

  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/model/fsl_model_weights.json');
      _modelData = jsonDecode(jsonStr) as Map<String, dynamic>;

      final weights = _modelData!['weights'] as Map<String, dynamic>;
      _w1 = _toMatrix(weights['net.0.weight']);
      _b1 = _toVector(weights['net.0.bias']);
      _w2 = _toMatrix(weights['net.3.weight']);
      _b2 = _toVector(weights['net.3.bias']);
      _w3 = _toMatrix(weights['net.6.weight']);
      _b3 = _toVector(weights['net.6.bias']);
      _labels = (_modelData!['label_names'] as List<dynamic>).cast<String>();

      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
    }
  }

  Future<void> loadTemporal() async {
    await temporalClassifier.load();
  }

  ClassificationResult classifyFused(List<LandmarkPoint> landmarks) {
    // Push to temporal buffer regardless
    final normalized = normalizeLandmarks(landmarks);
    landmarkBuffer.push(normalized);

    final staticResult = classify(landmarks);

    // Reset movement and alternatives
    _currentMovement = MovementType.unknown;
    _currentAlternatives = [];

    // Apply temporal label smoothing
    final smoothedLabel = _labelSmoother.smooth(staticResult.label);
    final smoothedResult = smoothedLabel != staticResult.label
        ? ClassificationResult(label: smoothedLabel, confidence: staticResult.confidence)
        : staticResult;

    // Movement detection + dictionary lookup (needs full buffer)
    if (landmarkBuffer.isFull) {
      final window = landmarkBuffer.getWindow();
      _currentMovement = _movementDetector.analyze(window);

      // Dictionary lookup: shape + movement
      final dictMatches = _gestureDictionary.lookup(
        smoothedResult.label,
        _currentMovement,
      );

      if (dictMatches.isNotEmpty) {
        _currentAlternatives = dictMatches.length > 1
            ? dictMatches.sublist(1)
            : [];
        return ClassificationResult(
          label: dictMatches.first,
          confidence: 0.9,
        );
      }

      // Temporal classifier
      if (temporalClassifier.isLoaded) {
        final temporalResult = temporalClassifier.classify(window);
        _tempConfidence = temporalResult.confidence;
        if (temporalResult.isRecognized &&
            temporalResult.confidence > smoothedResult.confidence) {
          return temporalResult;
        }
      }
    }

    return smoothedResult;
  }

  List<double> normalizeLandmarks(List<LandmarkPoint> landmarks) {
    final input = <double>[];
    if (landmarks.length >= 21) {
      final wrist = landmarks[0];
      final mcp = landmarks[9];
      final tip = landmarks[12];
      final dx = tip.x - mcp.x;
      final dy = tip.y - mcp.y;
      final dz = tip.z - mcp.z;
      final midLen = sqrt(dx * dx + dy * dy + dz * dz);
      final scale = midLen < 0.001 ? 1.0 : midLen;
      for (final pt in landmarks) {
        final cx = pt.x - wrist.x;
        final cy = pt.y - wrist.y;
        final cz = pt.z - wrist.z;
        input.addAll([cx / scale, cy / scale, cz / scale]);
      }
    }
    return input;
  }

  ClassificationResult classify(List<LandmarkPoint> landmarks) {
    if (landmarks.length < 21) {
      return const ClassificationResult(label: '', confidence: 0.0);
    }

    final shapeResult = classifyByShape(landmarks);

    // Use NN only when confident, otherwise fall back to shape recognizer
    if (_isLoaded) {
      final nnResult = _runInference(landmarks);
      if (nnResult.isRecognized && nnResult.confidence > shapeResult.confidence) {
        return nnResult;
      }
    }

    return shapeResult;
  }

  ClassificationResult _runInference(List<LandmarkPoint> landmarks) {
    // Preprocess identically to training: wrist-center + normalize by middle finger length
    // Uses image-space (x,y,z) to match the training CSV data format
    final input = <double>[];
    if (landmarks.length >= 21) {
      final wrist = landmarks[0];
      
      // Compute middle finger length: distance from MCP (9) to TIP (12)
      final mcp = landmarks[9];
      final tip = landmarks[12];
      final dx = tip.x - mcp.x;
      final dy = tip.y - mcp.y;
      final dz = tip.z - mcp.z;
      final midLen = sqrt(dx * dx + dy * dy + dz * dz);
      final scale = midLen < 0.001 ? 1.0 : midLen;
      
      for (final pt in landmarks) {
        // Wrist-center, then normalize by middle finger length
        final cx = pt.x - wrist.x;
        final cy = pt.y - wrist.y;
        final cz = pt.z - wrist.z;
        input.addAll([cx / scale, cy / scale, cz / scale]);
      }
    } else {
      for (final pt in landmarks) {
        input.addAll([pt.x, pt.y, pt.z]);
      }
    }

    var h = _linear(input, _w1!, _b1!);
    h = _relu(h);
    h = _linear(h, _w2!, _b2!);
    h = _relu(h);
    h = _linear(h, _w3!, _b3!);
    final probs = _softmax(h);

    double maxProb = probs[0];
    int maxIdx = 0;
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        maxIdx = i;
      }
    }

    final label = maxIdx < _labels.length ? _labels[maxIdx] : 'Unknown';
    return ClassificationResult(label: label, confidence: maxProb);
  }

  List<double> _linear(List<double> input, List<List<double>> weight, List<double> bias) {
    final out = List.filled(bias.length, 0.0);
    for (int i = 0; i < weight.length; i++) {
      double sum = bias[i];
      final row = weight[i];
      for (int j = 0; j < input.length; j++) {
        sum += row[j] * input[j];
      }
      out[i] = sum;
    }
    return out;
  }

  List<double> _relu(List<double> x) => x.map((v) => v > 0 ? v : 0.0).toList();

  List<double> _softmax(List<double> x) {
    double max = x.reduce((a, b) => a > b ? a : b);
    double sum = 0;
    final result = <double>[];
    for (final v in x) {
      final e = exp(v - max);
      result.add(e);
      sum += e;
    }
    return result.map((v) => v / sum).toList();
  }

  List<List<double>> _toMatrix(dynamic data) {
    final list = data as List<dynamic>;
    return list.map((row) => (row as List<dynamic>).cast<double>()).toList();
  }

  List<double> _toVector(dynamic data) {
    return (data as List<dynamic>).cast<double>();
  }

  /// Real-time shape-based classification using live hand landmarks.
  /// Used when no trained model weights are available.
  List<double> getFingerExtensions(List<LandmarkPoint> landmarks) {
    return _shapeRecognizer.getFingerExtensions(landmarks);
  }

  ClassificationResult classifyByShape(List<LandmarkPoint> landmarks) {
    if (landmarks.length < 21) {
      return const ClassificationResult(label: '', confidence: 0.0);
    }
    final rawLabel = _shapeRecognizer.classify(landmarks);
    final label = HandShapeRecognizer.signNameForShape(rawLabel);
    final ext = _shapeRecognizer.getFingerExtensions(landmarks);
    final count = ext.where((e) => e > 0.55).length;
    final confidence = (count == 0 || count >= 4) ? 0.85 : 0.75;
    return ClassificationResult(label: label, confidence: confidence);
  }

  void dispose() {}
}

class TemporalSmoother {
  final int windowSize;
  final double threshold;
  final _buffer = <String>[];

  TemporalSmoother({this.windowSize = 10, this.threshold = 0.6});

  String smooth(String label) {
    _buffer.add(label);
    if (_buffer.length > windowSize) _buffer.removeAt(0);
    if (_buffer.length < windowSize ~/ 2) return label;

    final counts = <String, int>{};
    for (final l in _buffer) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return top.value / _buffer.length >= threshold ? top.key : _buffer.last;
  }

  void reset() => _buffer.clear();
}
