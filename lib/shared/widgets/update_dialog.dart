import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Shows the "Update available" dialog for [info].
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !info.force,
    builder: (_) => UpdateDialog(info: info),
  );
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdatePhase { ready, downloading, needsPermission, error }

class _UpdateDialogState extends State<UpdateDialog> {
  final _service = UpdateService.instance;

  var _phase = _UpdatePhase.ready;
  double? _progress;
  int _received = 0;
  String? _error;
  String? _hint;

  UpdateInfo get _info => widget.info;

  bool get _canPop =>
      _phase != _UpdatePhase.downloading &&
      (_phase != _UpdatePhase.ready || !_info.force);

  Future<void> _startUpdate() async {
    if (await _service.canInstall()) {
      await _downloadAndInstall();
    } else if (mounted) {
      setState(() => _phase = _UpdatePhase.needsPermission);
    }
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = null;
      _received = 0;
      _error = null;
      _hint = null;
    });

    try {
      final file = await _service.existingApk(_info) ??
          await _service.download(_info, (progress, received) {
            if (mounted) {
              setState(() {
                _progress = progress;
                _received = received;
              });
            }
          });
      if (!mounted) return;
      await _service.install(file);
      // The system installer now covers the app; drop the dialog. If the
      // install succeeds Android restarts the process anyway.
      if (mounted) Navigator.of(context).pop();
    } on UpdateCancelled {
      if (mounted) setState(() => _phase = _UpdatePhase.ready);
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _UpdatePhase.error;
          _error = 'Download failed. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _continueAfterSettings() async {
    if (await _service.canInstall()) {
      await _downloadAndInstall();
    } else if (mounted) {
      setState(() => _hint = 'Permission is still off — enable "Allow from this source" for iSign.');
    }
  }

  void _dismiss() {
    if (!_info.force) _service.skipVersion(_info.versionCode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionLabel = _info.versionName.isNotEmpty
        ? 'v${_info.versionName} (build ${_info.versionCode})'
        : 'build ${_info.versionCode}';

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_info.force) {
          _service.skipVersion(_info.versionCode);
        }
      },
      child: AlertDialog(
        icon: Icon(Icons.system_update, color: theme.colorScheme.primary, size: 32),
        title: const Text('Update available'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: _buildContent(theme, versionLabel),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, String versionLabel) {
    switch (_phase) {
      case _UpdatePhase.ready:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version of iSign is ready: $versionLabel'),
            if (_info.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_info.notes, style: theme.textTheme.bodySmall),
            ],
          ],
        );
      case _UpdatePhase.downloading:
        final mb = (_received / (1024 * 1024)).toStringAsFixed(1);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Downloading update… ($mb MB)'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            if (_progress != null) ...[
              const SizedBox(height: 8),
              Text('${(_progress! * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        );
      case _UpdatePhase.needsPermission:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'For security, Android must allow iSign to install apps. '
                'Open settings, turn on "Allow from this source", then tap Continue.'),
            if (_hint != null) ...[
              const SizedBox(height: 12),
              Text(_hint!, style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error)),
            ],
          ],
        );
      case _UpdatePhase.error:
        return Text(_error ?? 'Something went wrong.');
    }
  }

  List<Widget> _buildActions() {
    switch (_phase) {
      case _UpdatePhase.ready:
        return [
          if (!_info.force)
            TextButton(onPressed: _dismiss, child: const Text('Later')),
          FilledButton(onPressed: _startUpdate, child: const Text('Update')),
        ];
      case _UpdatePhase.downloading:
        return [
          TextButton(
            onPressed: () {
              _service.cancelDownload();
            },
            child: const Text('Cancel'),
          ),
        ];
      case _UpdatePhase.needsPermission:
        return [
          TextButton(onPressed: _dismiss, child: const Text('Close')),
          TextButton(
            onPressed: _service.openInstallSettings,
            child: const Text('Open settings'),
          ),
          FilledButton(
            onPressed: _continueAfterSettings,
            child: const Text('Continue'),
          ),
        ];
      case _UpdatePhase.error:
        return [
          TextButton(onPressed: _dismiss, child: const Text('Close')),
          FilledButton(onPressed: _startUpdate, child: const Text('Retry')),
        ];
    }
  }
}
