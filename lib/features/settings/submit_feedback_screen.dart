import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/database/db_helper.dart';
import '../../data/models/fsl_sign_model.dart';

class SubmitFeedbackScreen extends StatefulWidget {
  const SubmitFeedbackScreen({super.key});

  @override
  State<SubmitFeedbackScreen> createState() => _SubmitFeedbackScreenState();
}

class _SubmitFeedbackScreenState extends State<SubmitFeedbackScreen> {
  final _commentController = TextEditingController();
  List<FslSignModel> _signs = [];
  FslSignModel? _selectedSign;
  int _rating = 0;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSigns();
  }

  Future<void> _loadSigns() async {
    final db = await DbHelper().database;
    final maps = await db.query('fsl_signs', orderBy: 'sign_name ASC');

    if (!mounted) return;
    setState(() {
      _signs = maps.map((m) => FslSignModel.fromMap(m)).toList();
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedSign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sign')),
      );
      return;
    }
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give a rating')),
      );
      return;
    }

    setState(() => _submitting = true);

    final db = await DbHelper().database;
    await db.insert('feedback', {
      'sign_id': _selectedSign!.id,
      'rating': _rating,
      'comment': _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Feedback')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'We value your input!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Help us improve by rating a sign and sharing your thoughts.',
                  style: TextStyle(fontSize: 15, color: context.textSecondary),
                ),
                const SizedBox(height: 24),

                const Text('Select a Sign', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<FslSignModel>(
                  value: _selectedSign,
                  isExpanded: true,
                  hint: const Text('Choose a sign...'),
                  items: _signs.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.signName));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSign = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.pan_tool),
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Rating', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIdx = i + 1;
                    return IconButton(
                      icon: Icon(
                        starIdx <= _rating ? Icons.star : Icons.star_border,
                        size: 44,
                        color: starIdx <= _rating ? Colors.amber : AppColors.disabled,
                      ),
                      onPressed: () => setState(() => _rating = starIdx),
                    );
                  }),
                ),
                if (_rating > 0)
                  Center(
                    child: Text(
                      ['Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating - 1],
                      style: TextStyle(fontSize: 14, color: context.textSecondary),
                    ),
                  ),

                const SizedBox(height: 24),
                const Text('Comment (optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Share your experience with this sign...',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Feedback'),
                  ),
                ),
              ],
            ),
    );
  }
}
