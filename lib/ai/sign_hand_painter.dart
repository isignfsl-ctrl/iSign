import 'package:flutter/material.dart';

/// Returns [thumb, index, middle, ring, pinky] extension booleans for a sign.
List<bool> fingerExtensionsForSign(String signName) {
  switch (signName.toLowerCase()) {
    case 'yes':
      return [false, false, false, false, false]; // fist

    case 'no':
    case 'one':
      return [false, true, false, false, false]; // point index

    case "i'm fine":
    case "i'm fine!":
    case 'good':
      return [true, false, false, false, false]; // thumbs up

    case 'two':
    case 'peace':
      return [false, true, true, false, false]; // peace

    case 'three':
      return [false, true, true, true, false]; // three

    case 'four':
      return [false, true, true, true, true]; // four

    case 'i love you':
      return [true, true, false, false, true]; // ILY sign

    case 'ok':
    case 'okay':
      return [true, true, false, false, false]; // ok sign

    default:
      return [true, true, true, true, true]; // open palm
  }
}

/// Returns a human-readable string describing which fingers to extend.
String handShapeInstruction(String signName) {
  final ext = fingerExtensionsForSign(signName);
  final fingerNames = ['thumb', 'index', 'middle', 'ring', 'pinky'];
  final extended = <String>[];
  final count = ext.where((e) => e).length;

  if (count == 0) return 'Make a fist';
  if (count == 5) return 'Open palm, all fingers extended';

  for (int i = 0; i < 5; i++) {
    if (ext[i]) extended.add(fingerNames[i]);
  }

  if (extended.length == 1) return 'Extend ${extended[0]} finger';
  if (extended.length == 2) return 'Extend ${extended[0]} + ${extended[1]}';

  final last = extended.removeLast();
  return 'Extend ${extended.join(", ")} + $last';
}

class SignHandPainter extends CustomPainter {
  final List<bool> fingerExtensions;

  SignHandPainter({required this.fingerExtensions})
      : assert(fingerExtensions.length == 5);

  // Base landmark positions (hand facing forward, unit square 0-1)
  static const _lm = <int, Offset>{
    0: Offset(0.50, 0.85),   // wrist
    1: Offset(0.25, 0.65),   // thumb CMC
    2: Offset(0.18, 0.55),   // thumb MCP
    3: Offset(0.14, 0.48),   // thumb IP
    4: Offset(0.10, 0.40),   // thumb TIP
    5: Offset(0.38, 0.55),   // index MCP
    6: Offset(0.38, 0.40),   // index PIP
    7: Offset(0.38, 0.28),   // index DIP
    8: Offset(0.38, 0.15),   // index TIP
    9: Offset(0.50, 0.52),   // middle MCP
    10: Offset(0.50, 0.35),  // middle PIP
    11: Offset(0.50, 0.22),  // middle DIP
    12: Offset(0.50, 0.08),  // middle TIP
    13: Offset(0.62, 0.55),  // ring MCP
    14: Offset(0.62, 0.40),  // ring PIP
    15: Offset(0.62, 0.28),  // ring DIP
    16: Offset(0.62, 0.15),  // ring TIP
    17: Offset(0.72, 0.60),  // pinky MCP
    18: Offset(0.72, 0.47),  // pinky PIP
    19: Offset(0.72, 0.37),  // pinky DIP
    20: Offset(0.72, 0.30),  // pinky TIP
  };

  // Finger topology: [mcp, pip, dip, tip] for each of 5 fingers
  static const _fingers = [
    [1, 2, 3, 4],   // thumb
    [5, 6, 7, 8],   // index
    [9, 10, 11, 12], // middle
    [13, 14, 15, 16], // ring
    [17, 18, 19, 20], // pinky
  ];

  // Palm connections
  static const _palmEdges = [
    (0, 5), (5, 9), (9, 13), (13, 17), (17, 0),
  ];

  // Palm center for curled finger calculation
  static final _palmCenter = Offset(0.48, 0.60);

  Offset _curledTip(Offset mcp, Offset tip, Offset palmCenter) {
    final dir = palmCenter - mcp;
    return mcp + dir * 0.55;
  }

  Offset _curledMid(Offset mcp, Offset tip, Offset palmCenter) {
    final dir = palmCenter - mcp;
    return mcp + dir * 0.35;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Compute adjusted landmark positions based on finger extensions
    final positions = <int, Offset>{};

    for (int i = 0; i < _fingers.length; i++) {
      final idx = _fingers[i];
      final mcp = _lm[idx[0]]!;
      final pip = _lm[idx[1]]!;
      final dip = _lm[idx[2]]!;
      final tip = _lm[idx[3]]!;
      final extended = fingerExtensions[i];

      positions[idx[0]] = mcp; // MCP always at base position

      if (extended) {
        positions[idx[1]] = pip;
        positions[idx[2]] = dip;
        positions[idx[3]] = tip;
      } else {
        positions[idx[1]] = Offset.lerp(mcp, _curledMid(mcp, tip, _palmCenter), 0.5)!;
        positions[idx[2]] = Offset.lerp(mcp, _curledMid(mcp, tip, _palmCenter), 0.7)!;
        positions[idx[3]] = _curledTip(mcp, tip, _palmCenter);
      }
    }

    // Wrist stays at base
    positions[0] = _lm[0]!;

    // Scale and center
    Offset scalePt(Offset p) {
      final dx = (p.dx - 0.5) * scale * 0.85 + centerX;
      final dy = (p.dy - 0.15) * scale * 0.75 + centerY * 0.2;
      return Offset(dx, dy);
    }

    // Paint palm fill
    final palmPath = Path();
    final palmPts = [0, 5, 9, 13, 17];
    for (int i = 0; i < palmPts.length; i++) {
      final pt = scalePt(positions[palmPts[i]]!);
      if (i == 0) {
        palmPath.moveTo(pt.dx, pt.dy);
      } else {
        palmPath.lineTo(pt.dx, pt.dy);
      }
    }
    palmPath.close();
    canvas.drawPath(palmPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill);

    // Paint palm edges
    final palmPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final e in _palmEdges) {
      canvas.drawLine(scalePt(positions[e.$1]!), scalePt(positions[e.$2]!), palmPaint);
    }

    // Paint fingers
    final fingerPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointFillPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..style = PaintingStyle.fill;

    final jointBorderPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final finger in _fingers) {
      for (int j = 0; j < finger.length - 1; j++) {
        final a = scalePt(positions[finger[j]]!);
        final b = scalePt(positions[finger[j + 1]]!);
        canvas.drawLine(a, b, fingerPaint);
      }
    }

    // Paint joints
    for (int i = 0; i < 21; i++) {
      final pt = scalePt(positions[i]!);
      final radius = (i == 0 || i == 1 || i == 5 || i == 9 || i == 13 || i == 17) ? 3.5 : 2.8;
      canvas.drawCircle(pt, radius, jointFillPaint);
      canvas.drawCircle(pt, radius, jointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(SignHandPainter oldDelegate) =>
      oldDelegate.fingerExtensions != fingerExtensions;
}
