import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final String? tooltip;

  const StatusBadge(this.status, {super.key, this.fontSize = 11, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final label = status.toUpperCase();
    final tip = tooltip ?? _defaultTooltip(status);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );

    if (tip.isNotEmpty) {
      return Tooltip(message: tip, child: badge);
    }
    return badge;
  }

  String _defaultTooltip(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending — fewer than 5 approved recording samples. More recordings needed before this sign can be trained.';
      case 'approved':
        return 'Approved — recording has been reviewed and accepted.';
      case 'rejected':
        return 'Rejected — recording was not accepted for training.';
      case 'trained':
        return 'Trained — 5+ approved recording samples. Ready for use.';
      default:
        return '';
    }
  }

  Color _color() {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'approved':
        return AppColors.statusApproved;
      case 'rejected':
        return AppColors.statusRejected;
      default:
        return Colors.grey;
    }
  }
}
