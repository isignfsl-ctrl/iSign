import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/theme_extensions.dart';

/// "How to sync and get signs" tips.
///
/// Rendered as a full card on the Home tab and as a compact note under the
/// Show Translation History switch in Settings, so both places always teach
/// the same three steps: connect, sync, browse signs.
class SyncTipsCard extends StatelessWidget {
  /// true = inline note with smaller type (Settings); false = full card (Home).
  final bool compact;

  const SyncTipsCard({super.key, this.compact = false});

  static const _tips = [
    (
      icon: Icons.wifi_outlined,
      title: 'Connect to the internet',
      description: 'Use WiFi or mobile data so the app can reach the cloud.',
    ),
    (
      icon: Icons.sync,
      title: 'Sync Everything',
      description:
          'In Settings, scroll to Cloud Sync and tap Sync Everything to upload your recordings and download the latest signs.',
    ),
    (
      icon: Icons.pan_tool_outlined,
      title: 'Get new signs',
      description:
          'Once synced, open the Signs tab to browse, practice, and train new signs.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                compact ? Icons.tips_and_updates_outlined : Icons.sync,
                size: compact ? 16 : 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                compact ? 'Tip: Sync & Get Signs' : 'Sync & Get Signs',
                style: TextStyle(
                  fontSize: compact ? 12 : 16,
                  fontWeight: FontWeight.w600,
                  color: compact ? AppColors.primary : context.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          for (int i = 0; i < _tips.length; i++) ...[
            _buildTipRow(context, _tips[i]),
            if (i < _tips.length - 1) SizedBox(height: compact ? 6 : 10),
          ],
        ],
      ),
    );
  }

  Widget _buildTipRow(
    BuildContext context, ({
    IconData icon,
    String title,
    String description,
  }) tip,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(tip.icon, size: compact ? 15 : 18,
              color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.title,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  height: 1.3,
                ),
              ),
              Text(
                tip.description,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: context.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
