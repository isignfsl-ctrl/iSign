import 'dart:math';
import 'package:flutter/material.dart';

class DonutChart extends StatelessWidget {
  final Map<String, double> segments;
  final Map<String, Color> segmentColors;
  final double radius;
  final double strokeWidth;

  const DonutChart({
    super.key,
    required this.segments,
    required this.segmentColors,
    this.radius = 60,
    this.strokeWidth = 28,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: (radius + strokeWidth / 2) * 2,
          height: (radius + strokeWidth / 2) * 2,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments,
              segmentColors: segmentColors,
              total: total,
              radius: radius,
              strokeWidth: strokeWidth,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: segments.entries.map((entry) {
            final pct = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: segmentColors[entry.key] ?? Colors.grey)),
                  const SizedBox(width: 6),
                  Text('${entry.key} ($pct%)', style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, double> segments;
  final Map<String, Color> segmentColors;
  final double total;
  final double radius;
  final double strokeWidth;

  _DonutPainter({required this.segments, required this.segmentColors, required this.total, required this.radius, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double startAngle = -pi / 2;
    for (final entry in segments.entries) {
      final sweep = (entry.value / total) * 2 * pi;
      paint.color = segmentColors[entry.key] ?? Colors.grey;
      if (sweep > 0.01) {
        canvas.drawArc(rect, startAngle, sweep, false, paint);
      }
      startAngle += sweep;
    }

    paint.color = Colors.grey.withValues(alpha: 0.12);
    final remaining = 1.0 - segments.values.fold(0.0, (a, b) => a + b) / total;
    if (remaining > 0.01) {
      canvas.drawArc(rect, startAngle, remaining * 2 * pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}
