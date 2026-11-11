import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import 'hand_frame_painter.dart';

/// Parses stored hand-frame JSON into a list of 63-value frames.
///
/// Accepts both formats that exist in the wild:
///  - a plain JSON array (`training_samples.landmarks_json` and
///    `reference_landmarks.landmarks_json` — one sample per row, flat
///    63 x frameCount doubles), and
///  - the cloud `recordings` payload `{'frames': [[...], ...]}`.
///
/// Returns null when the payload is missing or holds no complete frame.
List<List<double>>? parseHandFrames(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    final List<dynamic> rawFrames;
    if (decoded is List) {
      rawFrames = [decoded];
    } else if (decoded is Map && decoded['frames'] is List) {
      rawFrames = decoded['frames'] as List<dynamic>;
    } else {
      return null;
    }
    final frames = <List<double>>[];
    for (final sample in rawFrames) {
      if (sample is! List || sample.isEmpty) continue;
      if (!sample.every((v) => v is num)) continue;
      final nums = <double>[for (final v in sample) (v as num).toDouble()];
      for (var i = 0; i + 62 < nums.length; i += 63) {
        frames.add(nums.sublist(i, i + 63));
      }
    }
    return frames.isEmpty ? null : frames;
  } catch (_) {
    // Malformed payload — treated as having no frame data.
    return null;
  }
}

/// Plays hand-landmark frames as an animated skeleton (same behaviour as the
/// admin panel's recording preview): play/pause, scrub, and 0.5x/1x/2x speed.
class HandFramePlayer extends StatefulWidget {
  const HandFramePlayer({
    super.key,
    required this.frames,
    this.handedness,
    this.height = 300,
    this.autoPlay = true,
  });

  final List<List<double>> frames;
  final String? handedness;
  final double height;
  final bool autoPlay;

  @override
  State<HandFramePlayer> createState() => _HandFramePlayerState();
}

class _HandFramePlayerState extends State<HandFramePlayer> {
  double _pos = 0;
  double _speed = 1;
  bool _playing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _playing = widget.autoPlay;
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || !_playing) return;
      setState(() {
        _pos += _speed;
        if (_pos >= widget.frames.length) _pos -= widget.frames.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frames = widget.frames;
    final idx = _pos.floor().clamp(0, frames.length - 1).toInt();
    final maxPos = frames.length > 1 ? (frames.length - 1).toDouble() : 1.0;
    final seconds = (frames.length * 0.033).toStringAsFixed(1);
    final info = <String>[
      if (widget.handedness != null) '${widget.handedness} hand',
      '${frames.length} frames',
      '${seconds}s',
    ].join('  ·  ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            color: AppColors.darkSurface,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: HandFramePainter(
                    frame: frames[idx],
                    hue: handHue(widget.handedness),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 8,
                left: 10,
                child: _overlayChip('Frame ${idx + 1} / ${frames.length}'),
              ),
              if (widget.handedness != null)
                Positioned(
                  top: 8,
                  right: 10,
                  child: _overlayChip('${widget.handedness} hand'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          IconButton(
            onPressed: frames.length > 1
                ? () => setState(() => _playing = !_playing)
                : null,
            tooltip: _playing ? 'Pause' : 'Play',
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: _pos.clamp(0.0, maxPos).toDouble(),
              min: 0,
              max: maxPos,
              onChanged: frames.length > 1
                  ? (v) => setState(() => _pos = v)
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 72,
            child: Text(
              '${idx + 1}/${frames.length}',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ]),
        Row(children: [
          Expanded(
            child: Text(
              info,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.5, label: Text('0.5x')),
              ButtonSegment(value: 1, label: Text('1x')),
              ButtonSegment(value: 2, label: Text('2x')),
            ],
            selected: {_speed},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _speed = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _overlayChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }
}

/// Opens a dialog that plays back one sign's recorded hand frames.
Future<void> showHandFrameDialog(
  BuildContext context, {
  required List<List<double>> frames,
  required String title,
  String? handedness,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to sign it — move the hand through the frames below.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              HandFramePlayer(frames: frames, handedness: handedness),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
