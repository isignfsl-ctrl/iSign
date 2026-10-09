class ClassificationResult {
  final String label;
  final double confidence;

  const ClassificationResult({required this.label, required this.confidence});

  bool get isRecognized => confidence >= 0.5;
}
