import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loader.dart';

class PendingSignsScreen extends StatefulWidget {
  const PendingSignsScreen({super.key});

  @override
  State<PendingSignsScreen> createState() => _PendingSignsScreenState();
}

class _PendingSignsScreenState extends State<PendingSignsScreen> {
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'all';
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
    setState(() { _searchQuery = ''; _categoryFilter = 'all'; });
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
        title: Text('$label ${_selectedIds.length} signs?'),
        content: Text('Are you sure you want to $label ${_selectedIds.length} selected signs?'),
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
      final batch = _fb.firestore.batch();
      for (final id in _selectedIds) {
        batch.update(_fb.firestore.collection('catalog').doc(id), {
          'status': 'rejected',
          'reviewedAt': DateTime.now().toIso8601String(),
          'reviewedBy': 'admin',
        });
      }
      await batch.commit();
    }
    if (mounted) {
      setState(() { _selectedIds.clear(); _selectMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${status == 'approved' ? 'Approved' : 'Rejected'} ${_selectedIds.length} signs'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onApprove(String docId) async {
    final doc = await _fb.firestore.collection('catalog').doc(docId).get();
    final data = doc.data();
    if (data == null) return;
    final signId = data['signId'] as int?;
    final landmarksPath = data['landmarkSamplePaths'] as List<dynamic>?;

    // Update catalog entry status
    await _fb.firestore.collection('catalog').doc(docId).update({
      'status': 'approved',
      'approvedAt': DateTime.now().toIso8601String(),
      'approvedBy': 'admin',
    });

    // Update device trust if proposedBy is a user
    try {
      final proposedBy = data['proposedBy'] as String?;
      if (proposedBy != null) {
        // Find device by ownerUid
        final deviceSnapshot = await _fb.firestore
            .collection('devices')
            .where('ownerUid', isEqualTo: proposedBy)
            .limit(1)
            .get();
        if (deviceSnapshot.docs.isNotEmpty) {
          await _fb.firestore.collection('devices').doc(deviceSnapshot.docs.first.id).update({
            'trust_approvedCount': FieldValue.increment(1),
            'lastReview': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _onReject(String docId) async {
    await _fb.firestore.collection('catalog').doc(docId).update({
      'status': 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': 'admin',
    });

    // Update device trust if proposedBy is a user
    try {
      final doc = await _fb.firestore.collection('catalog').doc(docId).get();
      final data = doc.data();
      if (data == null) return;
      final proposedBy = data['proposedBy'] as String?;
      if (proposedBy != null) {
        final deviceSnapshot = await _fb.firestore
            .collection('devices')
            .where('ownerUid', isEqualTo: proposedBy)
            .limit(1)
            .get();
        if (deviceSnapshot.docs.isNotEmpty) {
          await _fb.firestore.collection('devices').doc(deviceSnapshot.docs.first.id).update({
            'trust_rejectedCount': FieldValue.increment(1),
            'lastReview': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (_) {}
  }

  String _categoryName(int id) {
    final locale = PlatformDispatcher.instance.locale.languageCode;
    final isEnglish = locale == 'en';
    switch (id) {
      case 0: return isEnglish ? 'Alphabet' : 'Alpabeto';
      case 1: return isEnglish ? 'Common Phrases' : 'Mga Karaniwang Parirala';
      case 2: return isEnglish ? 'Numbers' : 'Mga Bilang';
      case 3: return isEnglish ? 'Basic Gestures' : 'Mga Pangunahing Galaw';
      default: return 'Category $id';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = _categoryFilter != 'all' || _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selectedIds.length} selected' : 'Pending Signs'),
        actions: [
          if (!_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Select multiple',
              onPressed: _toggleSelectMode,
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
          ],
          if (_selectMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: _toggleSelectMode,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchFilterBar(
              controller: _searchCtl,
              hintText: 'Search by sign name, category, or user...',
              onChanged: _onSearchChanged,
              filterOptions: [
                FilterChipOption('All Categories', 'all'),
                FilterChipOption(_categoryName(0), '0'),
                FilterChipOption(_categoryName(1), '1'),
                FilterChipOption(_categoryName(2), '2'),
                FilterChipOption(_categoryName(3), '3'),
              ],
              selectedFilter: _categoryFilter,
              onFilterChanged: (v) => setState(() => _categoryFilter = v ?? 'all'),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fb.firestore
            .collection('catalog')
            .where('status', isEqualTo: 'pending')
            .orderBy('proposedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Error loading pending signs',
              subtitle: snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final signName = (data['signName'] as String? ?? '').toLowerCase();
            final categoryId = data['categoryId'] as int? ?? -1;
            final categoryMatch = _categoryFilter == 'all' || categoryId.toString() == _categoryFilter;
            final searchMatch = _searchQuery.isEmpty || signName.contains(_searchQuery);
            return categoryMatch && searchMatch;
          }).toList();

          if (filteredDocs.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.pending_actions,
              title: 'No pending signs',
              subtitle: hasFilters ? 'Try adjusting your filters' : 'All caught up! No signs awaiting review.',
            );
          }

          if (_selectMode) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final signName = data['signName'] as String? ?? 'Unknown';
                final categoryId = data['categoryId'] as int? ?? -1;
                final proposedAt = data['proposedAt'] as String?;
                final proposedBy = data['proposedBy'] as String?;
                final isSelected = _selectedIds.contains(doc.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(doc.id),
                    title: Text(signName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: ${_categoryName(categoryId)}'),
                        if (proposedAt != null)
                          Text('Proposed: ${DateTime.parse(proposedAt).toLocal().toString().substring(0, 16)}'),
                        if (proposedBy != null)
                          Text('By: $proposedBy'),
                      ],
                    ),
                    secondary: const Icon(Icons.pending),
                  ),
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final signName = data['signName'] as String? ?? 'Unknown';
              final description = data['description'] as String? ?? '';
              final categoryId = data['categoryId'] as int? ?? -1;
              final proposedAt = data['proposedAt'] as String?;
              final proposedBy = data['proposedBy'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showDetailsDialog(doc.id, data),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.statusPending.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.pending,
                            color: AppColors.statusPending,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                signName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const StatusBadge('pending'),
                                  const SizedBox(width: 12),
                                  Text(
                                    _categoryName(categoryId),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              if (proposedAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Proposed: ${DateTime.parse(proposedAt).toLocal().toString().substring(0, 16)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (proposedBy != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'By: $proposedBy',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'approve') {
                              _onApprove(doc.id);
                            } else if (value == 'reject') {
                              _onReject(doc.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'approve',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.statusApproved),
                                  SizedBox(width: 8),
                                  Text('Approve'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'reject',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, color: AppColors.statusRejected),
                                  SizedBox(width: 8),
                                  Text('Reject'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _selectMode
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusApproved,
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: Text('Approve ${_selectedIds.length}'),
                        onPressed: () => _batchAction('approved'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusRejected,
                        ),
                        icon: const Icon(Icons.cancel),
                        label: Text('Reject ${_selectedIds.length}'),
                        onPressed: () => _batchAction('rejected'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _showDetailsDialog(String docId, Map<String, dynamic> data) {
    final signName = data['signName'] as String? ?? 'Unknown';
    final description = data['description'] as String? ?? '';
    final englishName = data['english_name'] as String?;
    final englishDescription = data['english_description'] as String?;
    final categoryId = data['categoryId'] as int? ?? -1;
    final signId = data['signId'] as int?;
    final proposedAt = data['proposedAt'] as String?;
    final proposedBy = data['proposedBy'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(signName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.isNotEmpty) ...[
                Text('Description: $description', style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
              if (englishName != null && englishName.isNotEmpty) ...[
                Text('English Name: $englishName', style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
              if (englishDescription != null && englishDescription.isNotEmpty) ...[
                Text('English Description: $englishDescription', style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
              Text('Category: ${_categoryName(categoryId)}', style: Theme.of(ctx).textTheme.bodyMedium),
              if (signId != null) ...[
                const SizedBox(height: 4),
                Text('Sign ID: $signId', style: Theme.of(ctx).textTheme.bodyMedium),
              ],
              if (proposedAt != null) ...[
                const SizedBox(height: 4),
                Text('Proposed: ${DateTime.parse(proposedAt).toLocal().toString().substring(0, 16)}', style: Theme.of(ctx).textTheme.bodyMedium),
              ],
              if (proposedBy != null) ...[
                const SizedBox(height: 4),
                Text('Proposed By: $proposedBy', style: Theme.of(ctx).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusRejected),
            onPressed: () {
              Navigator.of(ctx).pop();
              _onReject(docId);
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusApproved),
            onPressed: () {
              Navigator.of(ctx).pop();
              _onApprove(docId);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}