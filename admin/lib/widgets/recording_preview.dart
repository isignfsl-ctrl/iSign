import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Plays back the hand-landmark frames stored inline in a `recordings`
/// document (`framesJson`) as an animated skeleton, so a reviewer can verify
/// that the sample actually represents the sign before approving it.
class RecordingPreview extends StatefulWidget {
  const RecordingPreview({
    super.key,
    required this.framesJson,
    this.height = 320,
  });

  final String? framesJson;
  final double height;

  @override
  State<RecordingPreview> createState() => _RecordingPreviewState();
}

class _RecordingPreviewState extends State<RecordingPreview> {
  List<List<double>>? _frames;
  int _sampleCount = 0;
  String? _handedness;
  double _pos = 0;
  double _speed = 1;
  bool _playing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _parse();
    if (_frames != null) {
      _playing = true;
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted || !_playing) return;
        setState(() {
          _pos += _speed;
          if (_pos >= _frames!.length) _pos -= _frames!.length;
        });
      });
    }
  }

  void _parse() {
    final raw = widget.framesJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final rawFrames = payload['frames'];
      if (rawFrames is! List) return;
      final frames = <List<double>>[];
      for (final sample in rawFrames) {
        if (sample is! List || sample.isEmpty) continue;
        if (!sample.every((v) => v is num)) continue;
        final nums = <double>[for (final v in sample) (v as num).toDouble()];
        for (var i = 0; i + 62 < nums.length; i += 63) {
          frames.add(nums.sublist(i, i + 63));
        }
      }
      if (frames.isEmpty) return;
      _frames = frames;
      _sampleCount = rawFrames.length;
      final h = payload['handedness'];
      if (h is String && h.isNotEmpty && h.toLowerCase() != 'unknown') {
        _handedness = h;
      }
    } catch (_) {
      // Malformed payload — treated as having no frame data.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_frames == null) return;
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frames = _frames;
    if (frames == null) return _emptyState();

    final idx = _pos.floor().clamp(0, frames.length - 1).toInt();
    final maxPos = frames.length > 1 ? (frames.length - 1).toDouble() : 1.0;
    final seconds = (frames.length * 0.033).toStringAsFixed(1);
    final info = <String>[
      if (_handedness != null) '$_handedness hand',
      '${frames.length} frames',
      if (_sampleCount > 1) '$_sampleCount samples',
      '${seconds}s',
    ].join('  ·  ');
    final hue = (_handedness ?? '').toLowerCase().contains('left') ? 210.0 : 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            color: AppColors.surfaceDark,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HandFramePainter(frame: frames[idx], hue: hue),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 8,
                left: 10,
                child: _overlayChip('Frame ${idx + 1} / ${frames.length}'),
              ),
              if (_handedness != null)
                Positioned(
                  top: 8,
                  right: 10,
                  child: _overlayChip('$_handedness hand'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          IconButton(
            onPressed: _togglePlay,
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

  Widget _emptyState() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.front_hand_outlined, size: 36, color: Colors.white54),
        const SizedBox(height: 10),
        const Text(
          'No frame data',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This recording has no stored hand frames to play back.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ]),
    );
  }
}

/// Opens a dialog that plays back the hand frames of one recording.
Future<void> showRecordingPreview(
  BuildContext context, {
  required String? framesJson,
  required String title,
  String? subtitle,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: Text('Preview — $title'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) ...[
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
              ],
              RecordingPreview(framesJson: framesJson, height: 340),
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

class _HandFramePainter extends CustomPainter {
  _HandFramePainter({required this.frame, required this.hue});

  /// One flattened frame: 21 landmarks x (x, y, z) = 63 doubles.
  final List<double> frame;
  final double hue;

  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [5, 9], [9, 10], [10, 11], [11, 12],
    [9, 13], [13, 14], [14, 15], [15, 16],
    [13, 17], [17, 18], [18, 19], [19, 20],
    [0, 17],
  ];

  static const _fingerTips = [4, 8, 12, 16, 20];

  Offset _pt(int i, Size size) =>
      Offset(frame[i * 3] * size.width, frame[i * 3 + 1] * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.length < 63) return;
    final s = size.shortestSide / 360.0;

    final bonePaint = Paint()
      ..color = HSLColor.fromAHSL(0.95, hue, 0.95, 0.55).toColor()
      ..strokeWidth = (3.5 * s).clamp(2.0, 6.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()..color = Colors.white;
    final tipPaint = Paint()..color = Colors.yellowAccent;
    final wristPaint = Paint()..color = Colors.redAccent;

    for (final conn in _connections) {
      canvas.drawLine(_pt(conn[0], size), _pt(conn[1], size), bonePaint);
    }

    canvas.drawCircle(_pt(0, size), 10 * s, wristPaint);
    for (var i = 1; i < 21; i++) {
      canvas.drawCircle(_pt(i, size), 5.5 * s, jointPaint);
    }
    for (final tip in _fingerTips) {
      canvas.drawCircle(_pt(tip, size), 8 * s, tipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandFramePainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.hue != hue;
}
