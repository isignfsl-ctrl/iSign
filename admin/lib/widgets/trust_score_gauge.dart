import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrustScoreGauge extends StatelessWidget {
  final double percentage;
  final double size;

  const TrustScoreGauge(this.percentage, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 70
        ? AppColors.trustHigh
        : percentage >= 40
            ? AppColors.trustMedium
            : AppColors.trustLow;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '${percentage.round()}%',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
