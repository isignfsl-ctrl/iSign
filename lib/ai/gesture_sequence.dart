import 'classification_result.dart';

class GestureSequence {
  static const _holdDuration = Duration(milliseconds: 300);
  static const _cooldownDuration = Duration(milliseconds: 300);
  static const _maxSequenceLength = 100;
  static const double _velocityThreshold = 0.015;
  static const double _highConfThreshold = 0.75;
  // Only a real end-of-thought pause closes a sentence. 800ms fired on
  // nearly every word (careful signing pauses that long), so the output
  // read as one short sentence per sign instead of flowing words.
  static const Duration _phrasePause = Duration(seconds: 3);

  final List<String> _sequence = [];
  final List<int> _phraseBreaks = [];

  String _stableLabel = '';
  DateTime? _sameLabelSince;
  DateTime? _cooldownUntil;
  DateTime? _lastWordAddedAt;
  String _currentLabel = '';
  double _currentConfidence = 0.0;
  double _currentVelocity = 0.0;

  List<String> get sequence => List.unmodifiable(_sequence);
  String get currentLabel => _currentLabel;
  double get currentConfidence => _currentConfidence;
  double get currentVelocity => _currentVelocity;
  bool get isEmpty => _sequence.isEmpty;

  /// The recognized signs joined as readable sentences: single spaces
  /// between words, a sentence break ('. ') at phrase pauses, always
  /// ending with a period.
  String get translatedText {
    if (_sequence.isEmpty) return '';
    final sb = StringBuffer();
    for (int i = 0; i < _sequence.length; i++) {
      if (i > 0) {
        // A phrase break closes the previous sentence; otherwise the words
        // flow together with a plain space.
        sb.write(_phraseBreaks.contains(i) ? '. ' : ' ');
      }
      sb.write(_sequence[i]);
    }
    sb.write('.');
    return sb.toString();
  }

  void update(ClassificationResult result, {double velocity = 0.0}) {
    final now = DateTime.now();
    _currentVelocity = velocity;

    if (!result.isRecognized) {
      _currentLabel = '';
      _currentConfidence = 0.0;
      _stableLabel = '';
      _sameLabelSince = null;
      return;
    }

    _currentLabel = result.label;
    _currentConfidence = result.confidence;

    final cd = _cooldownUntil;
    if (cd != null && now.isBefore(cd)) {
      return;
    }
    _cooldownUntil = null;

    if (result.label == _stableLabel) {
      _sameLabelSince ??= now;
    } else {
      _stableLabel = result.label;
      _sameLabelSince = now;
    }

    if (_sameLabelSince != null &&
        now.difference(_sameLabelSince!) >= _holdDuration) {
      final held = _sameLabelSince != null
          ? now.difference(_sameLabelSince!)
          : Duration.zero;
      final isHeldLong = held >= _holdDuration;
      final isStill = velocity <= _velocityThreshold;
      final isVeryConfident = result.confidence >= _highConfThreshold;

      if (isHeldLong && (isStill || isVeryConfident)) {
        if (_sequence.isEmpty || _sequence.last != result.label) {
          if (_sequence.length < _maxSequenceLength) {
            // Check for phrase break (pause between signs)
            if (_lastWordAddedAt != null &&
                now.difference(_lastWordAddedAt!) >= _phrasePause) {
              _phraseBreaks.add(_sequence.length);
            }
            _sequence.add(result.label);
            _lastWordAddedAt = now;
          }
        }
        _cooldownUntil = now.add(_cooldownDuration);
        _stableLabel = '';
        _sameLabelSince = null;
      }
    }
  }

  void setLive(ClassificationResult result, {double velocity = 0.0}) {
    _currentLabel = result.isRecognized ? result.label : '';
    _currentConfidence = result.isRecognized ? result.confidence : 0.0;
    _currentVelocity = velocity;
  }

  void reset() {
    _sequence.clear();
    _phraseBreaks.clear();
    _stableLabel = '';
    _sameLabelSince = null;
    _cooldownUntil = null;
    _lastWordAddedAt = null;
    _currentLabel = '';
    _currentConfidence = 0.0;
    _currentVelocity = 0.0;
  }

  String removeLast() {
    if (_sequence.isEmpty) return '';
    final removed = _sequence.removeLast();
    // Drop breaks that pointed at (or beyond) the removed word — a stale
    // index would later insert a '.' in the middle of a sentence.
    _phraseBreaks.removeWhere((b) => b >= _sequence.length);
    return removed;
  }
}
