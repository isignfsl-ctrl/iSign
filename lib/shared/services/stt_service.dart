import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  stt.SpeechToText? _speech;
  bool _available = false;
  bool _listening = false;
  bool _initAttempted = false;
  String _lastError = '';
  String _lastWords = '';

  bool get isAvailable => _available;
  bool get isListening => _listening;
  String get lastError => _lastError;

  Future<bool> init() async {
    if (_initAttempted) return _available;
    _initAttempted = true;
    _lastError = '';
    try {
      _speech = stt.SpeechToText();
      _available = await _speech!.initialize(
        onError: (error) => _lastError = error.errorMsg,
      );
    } catch (e) {
      _lastError = e.toString();
      _available = false;
    }
    return _available;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (!_available || _speech == null) return;
    try {
      _lastWords = '';
      await _speech!.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          _lastWords = text;
          onResult(text, result.finalResult);
        },
        localeId: localeId,
      );
      _listening = true;
    } catch (e) {
      _lastError = e.toString();
      onResult('', true);
    }
  }

  Future<String> stop() async {
    _listening = false;
    try {
      await _speech?.stop();
    } catch (_) {}
    return _lastWords;
  }

  void dispose() {
    _listening = false;
    _speech?.cancel();
    _speech = null;
  }
}
