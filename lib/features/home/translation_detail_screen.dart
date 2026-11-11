import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/models/translation_detail_model.dart';
import '../../data/repositories/translation_repository.dart';

class TranslationDetailScreen extends StatefulWidget {
  final int translationId;

  const TranslationDetailScreen({super.key, required this.translationId});

  @override
  State<TranslationDetailScreen> createState() =>
      _TranslationDetailScreenState();
}

class _TranslationDetailScreenState extends State<TranslationDetailScreen> {
  final _repo = TranslationRepository();
  String _createdAt = '';
  String _mode = 'realtime';
  List<TranslationDetailModel> _details = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadData();
      _loaded = true;
    }
  }

  Future<void> _loadData() async {
    final translation = await _repo.getTranslationById(widget.translationId);
    if (translation == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final details = await _repo.getDetailsForTranslation(widget.translationId);
    if (!mounted) return;
    setState(() {
      _createdAt = translation.createdAt ?? '';
      _mode = translation.mode;
      _details = details;
    });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Translation'),
        content: const Text('This translation will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _repo.deleteTranslation(widget.translationId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _createdAt.length >= 16
        ? '${_createdAt.substring(0, 10)}  ${_createdAt.substring(11, 16)}'
        : _createdAt;
    final isSpeech = _mode == 'speech';
    final modeIcon = isSpeech ? Icons.mic : Icons.videocam;
    final modeLabel = isSpeech ? 'Speech' : 'Gesture';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTime.isNotEmpty ? displayTime : 'Translation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isSpeech ? Colors.blue : AppColors.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(modeIcon, size: 18,
                    color: isSpeech ? Colors.blue : AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  modeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSpeech ? Colors.blue.shade700 : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_details.isNotEmpty)
            _buildSentenceCard()
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'No details found',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The whole conversation as one readable sentence.
  ///
  /// New records store the sentence in a single detail row; older records
  /// were stored one word per row, so the rows are joined here. Legacy
  /// `'|'` phrase-break rows become sentence-ending periods instead of
  /// showing up as literal pipes.
  static bool _isSentenceEnd(String s) =>
      s.endsWith('.') || s.endsWith('?') || s.endsWith('!');

  String _buildSentence() {
    final parts = <String>[];
    for (final detail in _details) {
      final raw = (detail.translatedText ?? '').trim();
      if (raw.isEmpty) continue;
      if (raw == '|') {
        // Legacy phrase break: close the previous word into a sentence.
        if (parts.isNotEmpty && !_isSentenceEnd(parts.last)) {
          parts[parts.length - 1] = '${parts.last}.';
        }
        continue;
      }
      parts.add(raw);
    }
    final sentence = parts.join(' ');
    if (sentence.isEmpty) return sentence;
    return _isSentenceEnd(sentence) ? sentence : '$sentence.';
  }

  Widget _buildSentenceCard() {
    final sentence = _buildSentence();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Translation',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sentence,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
