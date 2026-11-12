import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../shared/widgets/hand_frame_painter.dart';
import '../../shared/widgets/hand_frame_player.dart';
import 'sign_tutorial.dart';

/// Horizontal strip of sign-tutorial cards shown under the latest recognized
/// sentence in speech mode — one card per word of the sentence.
///
/// Cards with recorded data show the same skeleton image as the admin
/// panel's Recordings tab (tap to open the animated playback); registered
/// signs without recorded data show a "train this sign" placeholder; words
/// that are not registered signs at all show a "create this sign" card so
/// no word of the sentence is silently dropped.
class SignTutorialStrip extends StatelessWidget {
  const SignTutorialStrip({super.key, required this.items});

  final List<SignTutorialItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _SignTutorialCard(item: items[i]),
      ),
    );
  }
}

class _SignTutorialCard extends StatefulWidget {
  const _SignTutorialCard({required this.item});

  final SignTutorialItem item;

  @override
  State<_SignTutorialCard> createState() => _SignTutorialCardState();
}

class _SignTutorialCardState extends State<_SignTutorialCard> {
  List<List<double>>? _frames;

  @override
  void initState() {
    super.initState();
    // Parse once — the JSON can hold up to 30 frames (1,890 doubles).
    _frames = parseHandFrames(widget.item.framesJson);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final frames = _frames;

    return GestureDetector(
      onTap: frames == null
          ? null
          : () => showHandFrameDialog(
                context,
                frames: frames,
                title: item.signName,
                handedness: item.handedness,
              ),
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.unregistered
                ? Colors.white12
                : frames == null
                    ? Colors.white24
                    : AppColors.primary.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: item.unregistered
                  ? _buildUnregistered()
                  : frames != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CustomPaint(
                            painter: HandFramePainter(
                              // A single representative pose keeps the strip
                              // cheap: several animating skeletons would jank
                              // low-end devices. Animation lives in the
                              // tap-through dialog.
                              frame: frames[frames.length ~/ 2],
                              hue: handHue(item.handedness),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        )
                      : _buildPlaceholder(),
            ),
            const SizedBox(height: 6),
            Text(
              item.signName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: item.unregistered ? Colors.white70 : Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Word the dictionary does not know — say so plainly instead of
  /// implying the sign exists but is missing data.
  Widget _buildUnregistered() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off, size: 28, color: Colors.white38),
        const SizedBox(height: 6),
        const Text(
          'Not a registered sign',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Create this sign',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.warning,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.front_hand_outlined, size: 28, color: Colors.white38),
        const SizedBox(height: 6),
        const Text(
          'No image yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Train this sign',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.warning,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
