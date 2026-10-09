import 'dart:math';
import 'mediapipe_handler.dart';

class HandShapeRecognizer {
  /// Returns [0,1] finger extension values [thumb, index, middle, ring, pinky]
  /// using world-space (wx,wy) distances from MCP (base) to TIP.
  /// 0 = curled, 1 = extended.
  List<double> getFingerExtensions(List<LandmarkPoint> pts) {
    // MediaPipe landmark indices:
    //   thumb: 1=MCP, 2=PIP, 3=DIP, 4=TIP
    //   index: 5=MCP, 6=PIP, 7=DIP, 8=TIP
    //   middle: 9=MCP, 10=PIP, 11=DIP, 12=TIP
    //   ring: 13=MCP, 14=PIP, 15=DIP, 16=TIP
    //   pinky: 17=MCP, 18=PIP, 19=DIP, 20=TIP
    const mcpIndices = [1, 5, 9, 13, 17];
    const tipIndices = [4, 8, 12, 16, 20];

    // Use world coordinates (rotation/scale invariant)
    double midRef = 0.0;
    for (int f = 0; f < 5; f++) {
      final mcp = pts[mcpIndices[f]];
      final tip = pts[tipIndices[f]];
      final dx = tip.wx - mcp.wx;
      final dy = tip.wy - mcp.wy;
      final dz = tip.wz - mcp.wz;
      final d = sqrt(dx * dx + dy * dy + dz * dz);
      if (f == 2) midRef = d; // middle finger as reference
    }

    if (midRef < 0.001) midRef = 0.001;

    return List.generate(5, (f) {
      final mcp = pts[mcpIndices[f]];
      final tip = pts[tipIndices[f]];
      final dx = tip.wx - mcp.wx;
      final dy = tip.wy - mcp.wy;
      final dz = tip.wz - mcp.wz;
      final d = sqrt(dx * dx + dy * dy + dz * dz);
      return (d / midRef).clamp(0.0, 1.0);
    });
  }

  int countExtended(List<LandmarkPoint> pts) {
    final ext = getFingerExtensions(pts);
    return ext.where((e) => e > 0.55).length;
  }

  String classify(List<LandmarkPoint> pts) {
    if (pts.length < 21) return 'No hand';
    final ext = getFingerExtensions(pts);
    final count = ext.where((e) => e > 0.55).length;

    final t = ext[0];
    final i = ext[1];
    final m = ext[2];
    final r = ext[3];
    final p = ext[4];

    // Fist: all curled
    if (count == 0) return 'Yes';

    // OK sign: thumb+index tips close in world space
    if (t > 0.5 && i > 0.5) {
      final dx = pts[4].wx - pts[8].wx;
      final dy = pts[4].wy - pts[8].wy;
      final dz = pts[4].wz - pts[8].wz;
      final d = sqrt(dx * dx + dy * dy + dz * dz);
      if (d < 0.025) return 'OK';
    }

    // Six: thumb + pinky only
    if (t > 0.5 && i < 0.4 && m < 0.4 && r < 0.4 && p > 0.5) return 'Six';

    // ILY (I Love You): thumb + index + pinky
    if (t > 0.5 && i > 0.55 && m < 0.4 && r < 0.4 && p > 0.5) return 'ILY';

    // Eight: thumb + index L-shape (thumb horizontal, not pointing up)
    if (t > 0.5 && i > 0.55 && m < 0.4 && r < 0.4 && p < 0.4) {
      final thumbTipY = pts[4].wy;
      final thumbDipY = pts[3].wy;
      if (thumbTipY >= thumbDipY) return 'Eight';
    }

    // Thumbs up: only thumb extended
    if (t > 0.5 && i < 0.4 && m < 0.4 && r < 0.4 && p < 0.4) return "I'm fine";

    // Point: only index extended
    if (i > 0.55 && m < 0.4 && r < 0.4) return 'No';

    // Two (FSL Number): index + middle (V sign)
    if (i > 0.55 && m > 0.55 && r < 0.4) return 'Two';

    // Three (FSL): thumb + index + middle
    if (t > 0.5 && i > 0.55 && m > 0.55 && r < 0.4 && p < 0.4) return 'Three';

    // Three (approximate): index + middle + ring
    if (i > 0.55 && m > 0.55 && r > 0.55 && p < 0.4) return 'Three';

    // Four: all but thumb
    if (i > 0.55 && m > 0.55 && r > 0.55 && p > 0.55 && t < 0.4) return 'Four';

    // Five: all five extended
    if (t > 0.5 && i > 0.55 && m > 0.55 && r > 0.55 && p > 0.55) return 'Five';

    // Open palm: any 4+ extended
    if (count >= 4) return 'Hello';

    return '';
  }

  static String signNameForShape(String shapeLabel) {
    switch (shapeLabel) {
      case 'Hello':
      case 'Five':
        return 'Kamusta';
      case 'Yes':
        return 'Oo';
      case 'No':
        return 'Hindi';
      case 'One':
        return 'Isa';
      case 'Two':
        return 'Dalawa';
      case 'Three':
        return 'Tatlo';
      case 'Four':
        return 'Apat';
      case "I'm fine":
        return 'Mabuti naman';
      case 'OK':
        return 'OK';
      case 'Six':
        return 'Anim';
      case 'ILY':
        return 'Mahal Kita';
      case 'Eight':
        return 'Walo';
      default:
        return shapeLabel;
    }
  }
}
