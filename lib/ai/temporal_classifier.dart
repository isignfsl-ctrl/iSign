import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'classification_result.dart';

class TemporalClassifier {
  List<List<List<double>>>? _conv1Weight, _conv2Weight;
  List<double>? _conv1Bias, _conv2Bias;
  List<List<double>>? _fc1Weight, _fc2Weight;
  List<double>? _fc1Bias, _fc2Bias;
  List<String> _labels = [];
  bool _isLoaded = false;
  static const int _windowSize = 30;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/model/fsl_temporal_weights.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final w = data['weights'] as Map<String, dynamic>;

      _conv1Weight = _toConvWeight(w['conv1.weight']);
      _conv1Bias = _toVector(w['conv1.bias']);
      _conv2Weight = _toConvWeight(w['conv2.weight']);
      _conv2Bias = _toVector(w['conv2.bias']);
      _fc1Weight = _toMatrix(w['fc1.weight']);
      _fc1Bias = _toVector(w['fc1.bias']);
      _fc2Weight = _toMatrix(w['fc2.weight']);
      _fc2Bias = _toVector(w['fc2.bias']);
      _labels = (data['label_names'] as List<dynamic>).cast<String>();

      _isLoaded = true;
    } catch (_) {
      _isLoaded = false;
    }
  }

  ClassificationResult classify(List<List<double>> window) {
    if (!_isLoaded || window.length < _windowSize) {
      return const ClassificationResult(label: '', confidence: 0.0);
    }

    final convOut1 = _conv1d(window, _conv1Weight!, _conv1Bias!);
    final reluOut1 = _relu2d(convOut1);

    final convOut2 = _conv1d(reluOut1, _conv2Weight!, _conv2Bias!);
    final reluOut2 = _relu2d(convOut2);

    final pooled = _globalAvgPool(reluOut2);
    final fc1Out = _linear(pooled, _fc1Weight!, _fc1Bias!);
    final fc1Relu = _relu(fc1Out);

    final logits = _linear(fc1Relu, _fc2Weight!, _fc2Bias!);
    final probs = _softmax(logits);

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

  List<List<double>> _conv1d(
    List<List<double>> input,
    List<List<List<double>>> kernel,
    List<double> bias,
  ) {
    final t = input.length;
    final inCh = input[0].length;
    final kSize = kernel.length;
    final outCh = kernel[0][0].length;
    final pad = kSize ~/ 2;
    final out = List.generate(t, (_) => List.filled(outCh, 0.0));
    for (int ot = 0; ot < t; ot++) {
      for (int oc = 0; oc < outCh; oc++) {
        double sum = bias[oc];
        for (int k = 0; k < kSize; k++) {
          final it = ot + k - pad;
          if (it < 0 || it >= t) continue;
          for (int ic = 0; ic < inCh; ic++) {
            sum += input[it][ic] * kernel[k][ic][oc];
          }
        }
        out[ot][oc] = sum;
      }
    }
    return out;
  }

  List<double> _globalAvgPool(List<List<double>> input) {
    final t = input.length;
    final c = input[0].length;
    final out = List.filled(c, 0.0);
    for (int i = 0; i < t; i++) {
      for (int j = 0; j < c; j++) {
        out[j] += input[i][j];
      }
    }
    for (int j = 0; j < c; j++) {
      out[j] /= t;
    }
    return out;
  }

  List<double> _linear(
      List<double> input, List<List<double>> weight, List<double> bias) {
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

  List<double> _relu(List<double> x) =>
      x.map((v) => v > 0 ? v : 0.0).toList();

  List<List<double>> _relu2d(List<List<double>> x) =>
      x.map((row) => row.map((v) => v > 0 ? v : 0.0).toList()).toList();

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

  List<List<List<double>>> _toConvWeight(dynamic data) {
    final list = data as List<dynamic>;
    return list.map((kMat) {
      return (kMat as List<dynamic>)
          .map((row) => (row as List<dynamic>).cast<double>())
          .toList();
    }).toList();
  }

  void dispose() {}
}
