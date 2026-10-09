import 'package:flutter/material.dart';

class UserTypeBadge extends StatelessWidget {
  final String? userType;

  const UserTypeBadge({super.key, this.userType});

  @override
  Widget build(BuildContext context) {
    if (userType == null || userType!.isEmpty) return const SizedBox.shrink();
    final isDeaf = userType!.toLowerCase() == 'deaf';
    final color = isDeaf ? Colors.blue : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        userType!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
