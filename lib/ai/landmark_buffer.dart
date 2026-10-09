import 'dart:math';

class LandmarkBuffer {
  final int _capacity;
  final List<List<double>> _frames = [];
  int _head = 0;
  bool _full = false;

  LandmarkBuffer(this._capacity);

  int get length => _full ? _capacity : _frames.length;
  int get capacity => _capacity;
  bool get isFull => _full;

  void push(List<double> frame) {
    if (_frames.length < _capacity) {
      _frames.add(frame);
    } else {
      _frames[_head] = frame;
    }
    _head = (_head + 1) % _capacity;
    if (!_full && _frames.length == _capacity) _full = true;
  }

  List<List<double>> getWindow() {
    final result = List<List<double>>.generate(
      _capacity,
      (_) => List.filled(63, 0.0),
      growable: false,
    );
    if (!_full) {
      for (int i = 0; i < _frames.length; i++) {
        result[i] = List.from(_frames[i]);
      }
      return result;
    }
    for (int i = 0; i < _capacity; i++) {
      final idx = (_head + i) % _capacity;
      result[i] = List.from(_frames[idx]);
    }
    return result;
  }

  double velocity() {
    if (_frames.length < 2) return 0.0;
    final int lastIdx = _full ? (_head - 1 + _capacity) % _capacity : _frames.length - 1;
    final int prevIdx = _full ? (_head - 2 + _capacity) % _capacity : _frames.length - 2;
    final a = _frames[prevIdx];
    final b = _frames[lastIdx];
    double sum = 0.0;
    for (int i = 0; i < min(a.length, b.length); i++) {
      final d = b[i] - a[i];
      sum += d * d;
    }
    return sqrt(sum / min(a.length, b.length));
  }

  void clear() {
    _frames.clear();
    _head = 0;
    _full = false;
  }
}
