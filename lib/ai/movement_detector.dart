import 'dart:math';

enum MovementType { still, up, down, left, right, forward, wave, circular, unknown }

class MovementDetector {
  static const double _stillThreshold = 0.005;
  static const double _directionThreshold = 0.003;
  static const int _waveMinChanges = 2;
  static const int _waveWindow = 15;
  static const double _circularAngleThreshold = 5.0 * pi / 180;
  static const double _circularTotalAngle = pi;

  MovementType analyze(List<List<double>> window) {
    if (window.length < 3) return MovementType.unknown;

    final wristPositions = window
        .map((frame) => Vec3(frame[0], frame[1], frame[2]))
        .toList();

    final velocities = <Vec3>[];
    for (int i = 1; i < wristPositions.length; i++) {
      velocities.add(wristPositions[i] - wristPositions[i - 1]);
    }

    final rmsVel = _rms(velocities);
    if (rmsVel < _stillThreshold) return MovementType.still;

    if (_isWave(velocities)) return MovementType.wave;

    if (_isCircular(wristPositions)) return MovementType.circular;

    final mean = _mean(velocities);
    return _dominantDirection(mean);
  }

  bool _isWave(List<Vec3> velocities) {
    final start = max(0, velocities.length - _waveWindow);
    int changes = 0;
    for (int i = start + 1; i < velocities.length; i++) {
      final prev = velocities[i - 1].x;
      final curr = velocities[i].x;
      if ((prev > 0.001 && curr < -0.001) || (prev < -0.001 && curr > 0.001)) {
        changes++;
      }
    }
    return changes >= _waveMinChanges;
  }

  bool _isCircular(List<Vec3> positions) {
    if (positions.length < 8) return false;

    double cx = 0, cy = 0;
    for (final p in positions) {
      cx += p.x;
      cy += p.y;
    }
    cx /= positions.length;
    cy /= positions.length;

    double totalAngle = 0;
    for (int i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final curr = positions[i];

      final prevAngle = atan2(prev.y - cy, prev.x - cx);
      final currAngle = atan2(curr.y - cy, curr.x - cx);

      var delta = currAngle - prevAngle;
      if (delta > pi) delta -= 2 * pi;
      if (delta < -pi) delta += 2 * pi;

      if (delta.abs() > _circularAngleThreshold) {
        totalAngle += delta;
      }
    }

    return totalAngle.abs() > _circularTotalAngle;
  }

  MovementType _dominantDirection(Vec3 velocity) {
    final ax = velocity.x.abs();
    final ay = velocity.y.abs();
    final az = velocity.z.abs();

    if (ax > ay && ax > az && ax > _directionThreshold) {
      return velocity.x > 0 ? MovementType.right : MovementType.left;
    }
    if (ay > ax && ay > az && ay > _directionThreshold) {
      return velocity.y > 0 ? MovementType.down : MovementType.up;
    }
    if (az > _directionThreshold) {
      return velocity.z > 0 ? MovementType.unknown : MovementType.forward;
    }
    return MovementType.still;
  }

  double _rms(List<Vec3> velocities) {
    if (velocities.isEmpty) return 0;
    double sum = 0;
    for (final v in velocities) {
      sum += v.length * v.length;
    }
    return sqrt(sum / velocities.length);
  }

  Vec3 _mean(List<Vec3> velocities) {
    if (velocities.isEmpty) return Vec3(0, 0, 0);
    double sx = 0, sy = 0, sz = 0;
    for (final v in velocities) {
      sx += v.x;
      sy += v.y;
      sz += v.z;
    }
    final n = velocities.length;
    return Vec3(sx / n, sy / n, sz / n);
  }
}

MovementType velocityToMovement(Vec3 velocity) {
  const threshold = 0.003;
  final ax = velocity.x.abs();
  final ay = velocity.y.abs();
  final az = velocity.z.abs();

  if (ax > ay && ax > az && ax > threshold) {
    return velocity.x > 0 ? MovementType.right : MovementType.left;
  }
  if (ay > ax && ay > az && ay > threshold) {
    return velocity.y > 0 ? MovementType.down : MovementType.up;
  }
  if (az > threshold) {
    return velocity.z > 0 ? MovementType.unknown : MovementType.forward;
  }
  return MovementType.still;
}

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  double get length => sqrt(x * x + y * y + z * z);
}
