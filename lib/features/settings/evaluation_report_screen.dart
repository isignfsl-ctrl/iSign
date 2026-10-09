import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/database/db_helper.dart';

class EvaluationReportScreen extends StatefulWidget {
  const EvaluationReportScreen({super.key});

  @override
  State<EvaluationReportScreen> createState() => _EvaluationReportScreenState();
}

class _EvaluationReportScreenState extends State<EvaluationReportScreen> {
  Map<String, dynamic>? _stats;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadStats();
      _loaded = true;
    }
  }

  Future<void> _loadStats() async {
    final db = await DbHelper().database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt, COALESCE(SUM(total_signs),0) as total, '
      'COALESCE(SUM(recognized_signs),0) as recognized '
      'FROM evaluation_logs',
    );
    final avgAcc = await db.rawQuery(
      'SELECT AVG(accuracy_percentage) as avg FROM evaluation_logs',
    );
    final avgInf = await db.rawQuery(
      'SELECT AVG(avg_inference_ms) as avg FROM evaluation_logs',
    );
    final avgFps = await db.rawQuery(
      'SELECT AVG(avg_fps) as avg FROM evaluation_logs',
    );

    final row = totalResult.first;
    if (!mounted) return;
    setState(() {
      _stats = {
        'sessionCount': row['cnt'] as int? ?? 0,
        'totalSigns': (row['total'] as num?)?.toInt() ?? 0,
        'recognizedSigns': (row['recognized'] as num?)?.toInt() ?? 0,
        'avgAccuracy': (avgAcc.first['avg'] as num?)?.toDouble(),
        'avgInferenceMs': (avgInf.first['avg'] as num?)?.toDouble(),
        'avgFps': (avgFps.first['avg'] as num?)?.toDouble(),
      };
    });
  }

  Future<void> _exportPdf() async {
    if (_stats == null) return;
    final s = _stats!;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('iSign Evaluation Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Date: ${DateTime.now().toIso8601String().split('T').first}'),
            pw.SizedBox(height: 24),
            _pdfRow('Sessions Logged', s['sessionCount'].toString()),
            _pdfRow('Total Signs Attempted', s['totalSigns'].toString()),
            _pdfRow('Total Signs Recognized', s['recognizedSigns'].toString()),
            _pdfRow('Accuracy', s['avgAccuracy'] != null ? '${(s['avgAccuracy'] as double).toStringAsFixed(1)}%' : 'N/A'),
            _pdfRow('Avg Inference Time', s['avgInferenceMs'] != null ? '${(s['avgInferenceMs'] as double).toStringAsFixed(1)} ms' : 'N/A'),
            _pdfRow('Avg FPS', s['avgFps'] != null ? (s['avgFps'] as double).toStringAsFixed(1) : 'N/A'),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/iSign_evaluation_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 14)),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_stats == null) return;
    final s = _stats!;

    final rows = [
      ['Metric', 'Value'],
      ['Sessions Logged', s['sessionCount'].toString()],
      ['Total Signs Attempted', s['totalSigns'].toString()],
      ['Total Signs Recognized', s['recognizedSigns'].toString()],
      ['Accuracy', s['avgAccuracy'] != null ? '${(s['avgAccuracy'] as double).toStringAsFixed(1)}%' : 'N/A'],
      ['Avg Inference Time (ms)', s['avgInferenceMs'] != null ? (s['avgInferenceMs'] as double).toStringAsFixed(1) : 'N/A'],
      ['Avg FPS', s['avgFps'] != null ? (s['avgFps'] as double).toStringAsFixed(1) : 'N/A'],
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/iSign_evaluation_report.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluation Report')),
      body: _stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatCard(),
                const SizedBox(height: 24),
                _buildExportButtons(),
              ],
            ),
    );
  }

  Widget _buildStatCard() {
    final s = _stats!;
    final total = (s['totalSigns'] as int);
    final recognized = (s['recognizedSigns'] as int);
    final missed = total - recognized;
    final acc = s['avgAccuracy'] as double?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _statBox('Sessions', '${s['sessionCount']}', Icons.assessment),
              const SizedBox(width: 12),
              _statBox('Attempted', '$total', Icons.pan_tool),
              const SizedBox(width: 12),
              _statBox('Recognized', '$recognized', Icons.check_circle, Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          if (acc != null) ...[
            const Text('Accuracy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: acc / 100,
                minHeight: 12,
                backgroundColor: AppColors.disabled.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  acc >= 80 ? Colors.green : acc >= 50 ? Colors.orange : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${acc.toStringAsFixed(1)}% accuracy  |  $missed missed',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          if (s['avgInferenceMs'] != null)
            _perfRow('Avg Inference Time', '${(s['avgInferenceMs'] as double).toStringAsFixed(1)} ms'),
          if (s['avgFps'] != null)
            _perfRow('Avg FPS', (s['avgFps'] as double).toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon, [Color? color]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color ?? AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _perfRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: context.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildExportButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Export Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _exportBtn('Export PDF', Icons.picture_as_pdf, _exportPdf),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _exportBtn('Export CSV', Icons.table_chart, _exportCsv),
            ),
          ],
        ),
      ],
    );
  }

  Widget _exportBtn(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
