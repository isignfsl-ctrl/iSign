import 'package:flutter/material.dart';

class SkeletonCard extends StatefulWidget {
  final double height;
  final int lineCount;
  final bool hasAvatar;
  final double width;

  const SkeletonCard({super.key, this.height = 100, this.lineCount = 2, this.hasAvatar = false, this.width = double.infinity});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + _ctrl.value * 0.4,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: _buildShapes(baseColor),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShapes(Color base) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.hasAvatar)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: base)),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
              ],
            ),
          ),
        for (int i = 0; i < widget.lineCount; i++) ...[
          Container(
            height: 12,
            width: i == widget.lineCount - 1 ? 0.6 : 1.0,
            decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)),
          ),
          if (i < widget.lineCount - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int count;
  final double height;
  final int crossAxisCount;

  const SkeletonGrid({super.key, this.count = 6, this.height = 120, this.crossAxisCount = 2});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, childAspectRatio: 2.2, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (_, __) => SkeletonCard(height: height),
    );
  }
}
