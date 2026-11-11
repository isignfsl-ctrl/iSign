import 'package:flutter/material.dart';

/// Draws one hand-landmark frame (21 landmarks x (x, y, z) = 63 doubles) as a
/// skeleton.
///
/// This is a port of the admin panel's recorder preview painter, so the app's
/// speech-mode tutorial renders a sign's recorded data with exactly the same
/// visual as the Recordings tab on https://isign-fsl.web.app/.
class HandFramePainter extends CustomPainter {
  HandFramePainter({required this.frame, required this.hue});

  /// One flattened frame: 21 landmarks x (x, y, z) = 63 doubles.
  final List<double> frame;

  /// Skeleton colour hue: 210 for a left hand, 120 otherwise (matches admin).
  final double hue;

  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [5, 9], [9, 10], [10, 11], [11, 12],
    [9, 13], [13, 14], [14, 15], [15, 16],
    [13, 17], [17, 18], [18, 19], [19, 20],
    [0, 17],
  ];

  static const _fingerTips = [4, 8, 12, 16, 20];

  Offset _pt(int i, Size size) =>
      Offset(frame[i * 3] * size.width, frame[i * 3 + 1] * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.length < 63) return;
    final s = size.shortestSide / 360.0;

    final bonePaint = Paint()
      ..color = HSLColor.fromAHSL(0.95, hue, 0.95, 0.55).toColor()
      ..strokeWidth = (3.5 * s).clamp(2.0, 6.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()..color = Colors.white;
    final tipPaint = Paint()..color = Colors.yellowAccent;
    final wristPaint = Paint()..color = Colors.redAccent;

    for (final conn in _connections) {
      canvas.drawLine(_pt(conn[0], size), _pt(conn[1], size), bonePaint);
    }

    canvas.drawCircle(_pt(0, size), 10 * s, wristPaint);
    for (var i = 1; i < 21; i++) {
      canvas.drawCircle(_pt(i, size), 5.5 * s, jointPaint);
    }
    for (final tip in _fingerTips) {
      canvas.drawCircle(_pt(tip, size), 8 * s, tipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HandFramePainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.hue != hue;
}

/// Skeleton hue for a handedness label (left hand = blue-ish, otherwise green).
double handHue(String? handedness) =>
    (handedness ?? '').toLowerCase().contains('left') ? 210.0 : 120.0;
