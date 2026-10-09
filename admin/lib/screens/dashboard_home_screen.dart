import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/summary_card.dart';
import '../widgets/donut_chart.dart';
import '../widgets/skeleton_loader.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key});

  Map<String, int> _countByDay(List<QueryDocumentSnapshot> docs) {
    final today = DateTime.now().toUtc();
    final counts = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      counts['${d.month}/${d.day}'] = 0;
    }
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final submitted = data['submittedAt'] as String? ?? '';
      try {
        final dt = DateTime.parse(submitted).toUtc();
        final diff = today.difference(dt).inDays;
        if (diff >= 0 && diff <= 6) {
          counts['${dt.month}/${dt.day}'] = (counts['${dt.month}/${dt.day}'] ?? 0) + 1;
        }
      } catch (_) {}
    }
    return counts;
  }

  Map<String, int> _topSigns(List<QueryDocumentSnapshot> docs, {int limit = 5}) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['signName'] as String? ?? 'Unknown';
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(limit));
  }

  @override
  Widget build(BuildContext context) {
    final fb = AdminFirebaseService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Dashboard'),
            const SizedBox(width: 12),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.statusApproved,
                boxShadow: [BoxShadow(color: AppColors.statusApproved.withValues(alpha: 0.5), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 4),
            Text('Live', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.statusApproved)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: fb.firestore.collection('recordings').snapshots(),
        builder: (context, recSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: fb.firestore.collection('devices').snapshots(),
            builder: (context, devSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: fb.firestore.collection('catalog').snapshots(),
                builder: (context, catSnapshot) {
                  if (!recSnapshot.hasData || !devSnapshot.hasData || !catSnapshot.hasData) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        SkeletonGrid(count: 6, height: 110),
                        SizedBox(height: 24),
                        SkeletonCard(height: 180, lineCount: 1),
                        SizedBox(height: 24),
                        SkeletonCard(height: 200, lineCount: 1),
                      ],
                    );
                  }

                  int totalRec = 0, pending = 0, approved = 0, rejected = 0;
                  final recentDocs = <Map<String, dynamic>>[];
                  for (final doc in recSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] as String? ?? '';
                    totalRec++;
                    if (status == 'pending') { pending++; }
                    else if (status == 'approved') { approved++; }
                    else if (status == 'rejected') { rejected++; }
                    if (recentDocs.length < 10) { recentDocs.add(data); }
                  }

                  final totalDev = devSnapshot.hasData ? devSnapshot.data!.docs.length : 0;
                  final totalCat = catSnapshot.hasData ? catSnapshot.data!.docs.length : 0;
                  final trend = _countByDay(recSnapshot.data!.docs);
                  final topSigns = _topSigns(recSnapshot.data!.docs);
                  final isWide = MediaQuery.of(context).size.width > 800;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Overview', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _buildSummaryGrid(theme, totalRec, pending, approved, rejected, totalDev, totalCat),
                      if (totalRec > 0) ...[
                        const SizedBox(height: 24),
                        isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildSection(theme, 'Status Distribution',
                                    SizedBox(height: 140, child: DonutChart(
                                      segments: {'Pending': pending.toDouble(), 'Approved': approved.toDouble(), 'Rejected': rejected.toDouble()},
                                      segmentColors: {'Pending': AppColors.statusPending, 'Approved': AppColors.statusApproved, 'Rejected': AppColors.statusRejected},
                                    )),
                                  )),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildSection(theme, 'Activity (7 days)',
                                    SizedBox(height: 140, child: _SparklineChart(data: trend.values.toList(), labels: trend.keys.toList())),
                                  )),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildSection(theme, 'Status Distribution',
                                    SizedBox(height: 130, child: DonutChart(
                                      segments: {'Pending': pending.toDouble(), 'Approved': approved.toDouble(), 'Rejected': rejected.toDouble()},
                                      segmentColors: {'Pending': AppColors.statusPending, 'Approved': AppColors.statusApproved, 'Rejected': AppColors.statusRejected},
                                      radius: 50,
                                    )),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSection(theme, 'Activity (7 days)',
                                    SizedBox(height: 130, child: _SparklineChart(data: trend.values.toList(), labels: trend.keys.toList())),
                                  ),
                                ],
                              ),
                      ],
                      if (topSigns.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Top Signs', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _buildSignBarChart(theme, topSigns, totalRec),
                      ],
                      if (recentDocs.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Recent Activity', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _buildRecentActivity(theme, recentDocs),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Center(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(ThemeData theme, int total, int pending, int approved, int rejected, int devices, int catalog) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        SummaryCard(label: 'Total', count: total.toString(), icon: Icons.quiz, color: Colors.blue,
          trailing: pending > 0 ? Chip(label: Text('$pending', style: const TextStyle(fontSize: 10)),
            visualDensity: VisualDensity.compact, backgroundColor: AppColors.statusPending.withValues(alpha: 0.15), side: BorderSide.none) : null),
        SummaryCard(label: 'Pending', count: pending.toString(), icon: Icons.hourglass_empty, color: AppColors.statusPending),
        SummaryCard(label: 'Approved', count: approved.toString(), icon: Icons.check_circle, color: AppColors.statusApproved),
        SummaryCard(label: 'Rejected', count: rejected.toString(), icon: Icons.cancel, color: AppColors.statusRejected),
        SummaryCard(label: 'Devices', count: devices.toString(), icon: Icons.phone_android, color: Colors.purple),
        SummaryCard(label: 'Catalog', count: catalog.toString(), icon: Icons.book, color: Colors.teal),
      ],
    );
  }

  Widget _buildSignBarChart(ThemeData theme, Map<String, int> signs, int total) {
    final maxVal = signs.values.reduce(max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: signs.entries.map((entry) {
            final pct = maxVal > 0 ? entry.value / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text(entry.key, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 16,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 36, child: Text('${entry.value}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme, List<Map<String, dynamic>> docs) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(docs.length, (i) {
          if (i > 0) {
            return Column(
              children: [
                const Divider(height: 1),
                _activityTile(theme, docs[i]),
              ],
            );
          }
          return _activityTile(theme, docs[i]);
        }),
      ),
    );
  }

  Widget _activityTile(ThemeData theme, Map<String, dynamic> data) {
    final signName = data['signName'] as String? ?? 'Unknown';
    final status = data['status'] as String? ?? 'pending';
    final submittedAt = data['submittedAt'] as String? ?? '';
    final date = submittedAt.length >= 10 ? submittedAt.substring(0, 10) : '';
    final deviceId = (data['deviceId'] as String? ?? '');
    final shortDevice = deviceId.length > 16 ? '${deviceId.substring(0, 16)}...' : deviceId;
    final color = status == 'approved' ? AppColors.statusApproved : status == 'rejected' ? AppColors.statusRejected : AppColors.statusPending;
    return ListTile(
      dense: true,
      leading: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      title: Text(signName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Row(children: [
        Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        const Text('  \u00B7  ', style: TextStyle(fontSize: 12)),
        Text(date, style: theme.textTheme.bodySmall),
        if (shortDevice.isNotEmpty) ...[const Text('  \u00B7  ', style: TextStyle(fontSize: 12)), Text(shortDevice, style: theme.textTheme.bodySmall)],
      ]),
    );
  }
}

class _SparklineChart extends StatelessWidget {
  final List<int> data;
  final List<String> labels;
  const _SparklineChart({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(data: data.map((e) => e.toDouble()).toList(), color: Theme.of(context).colorScheme.primary),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels.map((l) => Text(l, style: const TextStyle(fontSize: 9))).toList(),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(max);
    if (maxVal == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path = Path();
    final fillPath = Path();
    final dx = size.width / (data.length - 1).clamp(1, data.length);

    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - (data[i] / maxVal) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((data.length - 1) * dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - (data[i] / maxVal) * (size.height - 4) - 2;
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) => true;
}
