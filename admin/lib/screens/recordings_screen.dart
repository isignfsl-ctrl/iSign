import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isign_shared/isign_shared.dart';
import '../services/admin_firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/recording_preview.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  final _fb = AdminFirebaseService();
  Timer? _debounce;
  bool _selectMode = false;
  final _selectedIds = <String>{};

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = v.toLowerCase());
    });
  }

  void _clearFilters() {
    _searchCtl.clear();
    setState(() { _searchQuery = ''; _statusFilter = 'all'; });
  }

  void _toggleSelectMode() {
    setState(() { _selectMode = !_selectMode; if (!_selectMode) _selectedIds.clear(); });
  }

  void _toggleSelection(String docId) {
    setState(() { if (_selectedIds.contains(docId)) { _selectedIds.remove(docId); } else { _selectedIds.add(docId); } });
  }

  Future<void> _batchAction(String status) async {
    if (_selectedIds.isEmpty) return;
    final label = status == 'approved' ? 'Approve' : 'Reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label ${_selectedIds.length} recordings?'),
        content: Text('Are you sure you want to $label ${_selectedIds.length} selected recordings?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: status == 'approved' ? AppColors.statusApproved : AppColors.statusRejected),
            onPressed: () => Navigator.of(ctx).pop(true), child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (status == 'approved') {
      for (final id in _selectedIds) {
        await _onApprove(id);
      }
    } else {
      final affectedSignIds = <int>{};
      for (final id in _selectedIds) {
        final d = await _fb.firestore.collection('recordings').doc(id).get();
        final sid = d.data()?['signId'] as int?;
        if (sid != null) affectedSignIds.add(sid);
      }
      final batch = _fb.firestore.batch();
      for (final id in _selectedIds) {
        batch.update(_fb.firestore.collection('recordings').doc(id), {
          'status': status, 'reviewedAt': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit();
      for (final sid in affectedSignIds) {
        await _recomputeApprovedCount(sid);
      }
    }
    if (mounted) {
      setState(() { _selectedIds.clear(); _selectMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${label.toLowerCase() == 'approve' ? 'Approved' : 'Rejected'} ${_selectedIds.length} recordings'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onApprove(String docId) async {
    final doc = await _fb.firestore.collection('recordings').doc(docId).get();
    final data = doc.data();
    if (data == null) return;
    final signId = data['signId'] as int?;

    // Update recording status
    await _fb.firestore.collection('recordings').doc(docId).update({
      'status': 'approved',
      'reviewedAt': DateTime.now().toIso8601String(),
    });

    // Update catalog entry (sample count, idempotent)
    if (signId != null) {
      await _recomputeApprovedCount(signId);
    }

    // Update device trust
    try {
      final deviceId = data['deviceId'] as String?;
      if (deviceId != null) {
        await _fb.firestore.collection('devices').doc(deviceId).update({
          'trust_approvedCount': FieldValue.increment(1),
          'lastReview': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  /// Recompute catalog `approvedSampleCount` for a sign as the number of
  /// SAMPLES contained in its approved recordings. Both approve and reject
  /// funnel through here instead of incrementing, so the value stays correct
  /// even when a recording's status changes more than once.
  Future<void> _recomputeApprovedCount(int signId) async {
    final snap = await _fb.firestore
        .collection('recordings')
        .where('signId', isEqualTo: signId)
        .where('status', isEqualTo: 'approved')
        .get();
    var total = 0;
    for (final d in snap.docs) {
      final fc = (d.data()['frameCount'] as num?)?.toInt();
      total += (fc != null && fc > 0) ? fc : 1;
    }
    final cat = await _fb.firestore
        .collection('catalog')
        .where('signId', isEqualTo: signId)
        .limit(1)
        .get();
    if (cat.docs.isNotEmpty) {
      await cat.docs.first.reference.update({'approvedSampleCount': total});
    }
  }

  void _exportCsv(List<QueryDocumentSnapshot> allDocs) {
    final rows = <String>[];
    rows.add('Sign ID,Sign Name,Status,Handedness,Frames,Duration (ms),Device ID,Submitted,Motion Score,Shape Consistency');
    for (final doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final r = RecordingMetadata.fromFirestore(data, doc.id);
      rows.add([
        r.signId, r.signName, r.status.name, r.handedness, r.frameCount, r.durationMs, r.deviceId,
        r.submittedAt.toIso8601String(),
        r.motionScore?.toStringAsFixed(3) ?? '', r.shapeConsistency?.toStringAsFixed(3) ?? '',
      ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(','));
    }
    final csv = rows.join('\n');
    final blob = html.Blob([csv], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute('download', 'recordings.csv');
    anchor.click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Exported ${rows.length - 1} recordings as CSV'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() { _debounce?.cancel(); _searchCtl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = _statusFilter != 'all' || _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selectedIds.length} selected' : 'Recordings'),
        actions: [
          if (!_selectMode) ...[
            IconButton(icon: const Icon(Icons.file_download), tooltip: 'Export CSV', onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Loading data for export...'), behavior: SnackBarBehavior.floating,
              ));
            }),
            IconButton(icon: const Icon(Icons.checklist), tooltip: 'Select multiple', onPressed: _toggleSelectMode),
          ],
          if (_selectMode)
            IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel selection', onPressed: _toggleSelectMode),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchFilterBar(
              controller: _searchCtl,
              hintText: 'Search by sign name or device...',
              onChanged: _onSearchChanged,
              selectedFilter: _statusFilter,
              onFilterChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              filterOptions: const [
                FilterChipOption('All', 'all'),
                FilterChipOption('Pending', 'pending'),
                FilterChipOption('Approved', 'approved'),
                FilterChipOption('Rejected', 'rejected'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _fb.firestore.collection('recordings').orderBy('submittedAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: List.generate(5, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonCard(height: 80, lineCount: 2))),
                );
              }

              var docs = snapshot.data!.docs;

              if (_statusFilter != 'all') {
                docs = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == _statusFilter).toList();
              }
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['signName'] as String? ?? '').toLowerCase();
                  final device = (data['deviceId'] as String? ?? '').toLowerCase();
                  final signId = data['signId']?.toString() ?? '';
                  return name.contains(_searchQuery) ||
                      device.contains(_searchQuery) ||
                      signId.contains(_searchQuery);
                }).toList();
              }

              final allDocs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Column(
                  children: [
                    if (hasFilters)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            Text('${docs.length} of ${allDocs.length} recordings', style: theme.textTheme.bodySmall),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _clearFilters, icon: const Icon(Icons.clear, size: 16), label: const Text('Clear filters'),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                      ),
                    const Expanded(child: EmptyStateWidget(icon: Icons.search_off, title: 'No recordings match your filter.')),
                  ],
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                itemCount: docs.length + (hasFilters ? 1 : 0),
                itemBuilder: (context, index) {
                  if (hasFilters && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('${docs.length} of ${allDocs.length} recordings', style: theme.textTheme.bodySmall),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text('\u00B7 "$_searchQuery"', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _clearFilters, icon: const Icon(Icons.clear, size: 16), label: const Text('Clear'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                          IconButton(
                            icon: const Icon(Icons.file_download, size: 18),
                            tooltip: 'Export filtered as CSV',
                            onPressed: () => _exportCsv(docs),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }

                  final docIndex = hasFilters ? index - 1 : index;
                  final doc = docs[docIndex];
                  final data = doc.data() as Map<String, dynamic>;
                  final recording = RecordingMetadata.fromFirestore(data, doc.id);
                  final color = _statusColor(recording.status);
                  final isPending = recording.status == RecordingStatus.pending;
                  final isSelected = _selectedIds.contains(doc.id);

                  Widget card = Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                    child: InkWell(
                      onTap: () {
                        if (_selectMode) { _toggleSelection(doc.id); }
                        else { _showDetail(context, recording, doc.id, data); }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (_selectMode) ...[Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(doc.id)), const SizedBox(width: 4)],
                            Container(width: 4, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(_signLabel(recording), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    if (recording.motionScore != null) _qualityBadge(recording.motionScore!),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text('${recording.handedness} · ${recording.frameCount} samples · ${recording.durationMs}ms', style: theme.textTheme.bodySmall),
                                  Text(recording.submittedAt.toLocal().toString().substring(0, 19), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (!_selectMode)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.play_circle_outline, size: 22),
                                  tooltip: 'Preview hand frames',
                                  onPressed: () => showRecordingPreview(
                                    context,
                                    framesJson: data['framesJson'] as String?,
                                    title: _signLabel(recording),
                                    subtitle: '${recording.deviceId} · ${recording.status.name}',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                StatusBadge(recording.status.name),
                              ]),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (isPending && !_selectMode) {
                    card = Dismissible(
                      key: ValueKey(doc.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: AppColors.statusApproved, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 24), child: const Icon(Icons.check, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: AppColors.statusRejected, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.close, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _onApprove(doc.id);
                        } else {
                          await _fb.firestore.collection('recordings').doc(doc.id).update({
                            'status': 'rejected', 'reviewedAt': DateTime.now().toIso8601String(),
                          });
                          final sid = data['signId'] as int?;
                          if (sid != null) await _recomputeApprovedCount(sid);
                        }
                        if (!context.mounted) return false;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(direction == DismissDirection.startToEnd ? 'Approved' : 'Rejected'),
                          behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1),
                        ));
                        return false;
                      },
                      child: card,
                    );
                  }

                  return card;
                },
              );
            },
          ),
          if (_selectMode && _selectedIds.isNotEmpty)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Text('${_selectedIds.length} selected', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () => _batchAction('approved'), icon: const Icon(Icons.check, size: 18), label: const Text('Approve'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.statusApproved.withValues(alpha: 0.2))),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _batchAction('rejected'), icon: const Icon(Icons.close, size: 18), label: const Text('Reject'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.statusRejected.withValues(alpha: 0.2))),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.pending: return AppColors.statusPending;
      case RecordingStatus.approved: return AppColors.statusApproved;
      case RecordingStatus.rejected: return AppColors.statusRejected;
    }
  }

  String _signLabel(RecordingMetadata r) =>
      r.signName.isEmpty ? 'Sign #${r.signId}' : r.signName;

  void _showDetail(BuildContext context, RecordingMetadata recording, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.9, expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Text(_signLabel(recording), style: theme.textTheme.titleLarge)),
                    StatusBadge(recording.status.name), const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                  ]),
                  const SizedBox(height: 16),
                  RecordingPreview(framesJson: data['framesJson'] as String?, height: 300),
                  const SizedBox(height: 16),
                  _section('Recording Info', [
                    _detailRow('Sign ID', recording.signId.toString()), _detailRow('Sign Name', recording.signName),
                    _detailRow('Handedness', recording.handedness), _detailRow('Samples', recording.frameCount.toString()),
                    _detailRow('Duration', '${recording.durationMs}ms'), _detailRow('Status', recording.status.name),
                  ]),
                  const Divider(height: 24),
                  _section('Device Info', [
                    _detailRow('Device ID', recording.deviceId), _detailRow('Recording ID', recording.recordingId),
                    if (recording.notes != null) _detailRow('Notes', recording.notes!),
                    if (recording.reviewedBy != null) _detailRow('Reviewed by', recording.reviewedBy!),
                  ]),
                  const Divider(height: 24),
                  _section('Timestamps', [
                    _detailRow('Submitted', recording.submittedAt.toLocal().toString().substring(0, 19)),
                    if (recording.reviewedAt != null) _detailRow('Reviewed', recording.reviewedAt!.toLocal().toString().substring(0, 19)),
                  ]),
                  if (recording.motionScore != null || recording.shapeConsistency != null) ...[
                    const Divider(height: 24),
                    _section('Quality Scores', [
                      if (recording.motionScore != null) _detailRow('Motion Score', '${(recording.motionScore! * 100).toStringAsFixed(0)}%'),
                      if (recording.shapeConsistency != null) _detailRow('Shape Consistency', '${(recording.shapeConsistency! * 100).toStringAsFixed(0)}%'),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  Text('Storage Path:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(4)),
                    child: Text(recording.landmarksPath, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                  if (recording.status == RecordingStatus.pending) ...[
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(child: FilledButton.tonalIcon(onPressed: () async {
                        await _onApprove(docId);
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)));
                        }
                      }, icon: const Icon(Icons.check), label: const Text('Approve'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusApproved.withValues(alpha: 0.2)))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton.tonalIcon(onPressed: () async {
                        await _fb.firestore.collection('recordings').doc(docId).update({'status': 'rejected', 'reviewedAt': DateTime.now().toIso8601String()});
                        await _recomputeApprovedCount(recording.signId);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)));
                        }
                      }, icon: const Icon(Icons.close), label: const Text('Reject'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusRejected.withValues(alpha: 0.2)))),
                    ]),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _qualityColor(double score) {
    if (score >= 0.8) return AppColors.statusApproved;
    if (score >= 0.5) return AppColors.statusPending;
    return AppColors.statusRejected;
  }

  Widget _qualityBadge(double motion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: _qualityColor(motion).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text('Q', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _qualityColor(motion))),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 8), ...rows,
    ]);
  }

  Widget _detailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}
