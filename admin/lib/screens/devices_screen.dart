import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_type_badge.dart';
import '../widgets/trust_score_gauge.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loader.dart';

String _relativeTime(String iso) {
  try {
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  } catch (_) {
    return iso.length > 19 ? iso.substring(0, 19) : iso;
  }
}

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _fb = AdminFirebaseService();
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _deleteDevice({required String deviceId, required String ownerName}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Remove "$ownerName" ($deviceId)?\n\nRecordings and training data from this device will remain in the database.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _fb.firestore.collection('devices').doc(deviceId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Device "$ownerName" deleted')),
      );
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = v.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Registered Devices')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by ID, name or email...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtl.clear(); _onSearchChanged(''); })
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _fb.firestore.collection('devices').orderBy('registeredAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonCard(height: 140, lineCount: 4, hasAvatar: true))),
                  );
                }

                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final id = d.id.toLowerCase();
                    final name = (data['ownerName'] as String? ?? '').toLowerCase();
                    final email = (data['ownerEmail'] as String? ?? '').toLowerCase();
                    return id.contains(_searchQuery) || name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return snapshot.data!.docs.isEmpty
                      ? const EmptyStateWidget(icon: Icons.phone_android, title: 'No devices registered.')
                      : const EmptyStateWidget(icon: Icons.search_off, title: 'No devices match your search.');
                }

                final isWide = MediaQuery.of(context).size.width > 800;

                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _buildDeviceCard(context, theme, doc);
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildDeviceCard(context, theme, docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, ThemeData theme, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final deviceId = doc.id;
    final ownerEmail = data['ownerEmail'] as String? ?? 'Unknown';
    final ownerName = data['ownerName'] as String? ?? '';
    final userType = data['userType'] as String? ?? '';
    final model = data['model'] as String? ?? '';
    final status = data['status'] as String? ?? 'unknown';
    final lastSync = data['lastSync'] as String? ?? '';
    final registeredAt = data['registeredAt'] as String? ?? '';
    final activeSessions = data['activeSessions'] as int? ?? 0;
    final totalUploads = data['totalUploads'] as int? ?? 0;
    final lastActive = data['lastActive'] as String? ?? '';
    final approvedCount = data['trust_approvedCount'] as int? ?? 0;
    final rejectedCount = data['trust_rejectedCount'] as int? ?? 0;
    final trustScore = approvedCount + rejectedCount > 0
        ? (approvedCount / (approvedCount + rejectedCount) * 100).round()
        : null;

    final isActive = status == 'active';
    final avatarLetter = ownerName.isNotEmpty ? ownerName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(avatarLetter, style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimaryContainer, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deviceId.length > 30 ? '${deviceId.substring(0, 30)}...' : deviceId, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (model.isNotEmpty) Text(model, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isActive ? AppColors.statusApproved.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? AppColors.statusApproved : Colors.grey)),
                    const SizedBox(width: 3),
                    Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? AppColors.statusApproved : Colors.grey)),
                  ]),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  tooltip: 'Delete device',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteDevice(deviceId: deviceId, ownerName: ownerName),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (ownerName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  Text(ownerName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  UserTypeBadge(userType: userType == 'deaf' ? 'Deaf' : 'Hearing'),
                ]),
              ),
            Text('Owner: $ownerEmail', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Row(
              children: [
                if (lastSync.isNotEmpty) Text('Sync: ${_relativeTime(lastSync)}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (lastSync.isNotEmpty && registeredAt.isNotEmpty) Text(' \u00B7 ', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (registeredAt.isNotEmpty) Text('Joined: ${registeredAt.length > 10 ? registeredAt.substring(0, 10) : registeredAt}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            if (activeSessions > 0 || totalUploads > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  Icon(Icons.trending_up,
                      size: 13, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$activeSessions sessions · $totalUploads uploads'
                      '${lastActive.isNotEmpty ? ' · active ${_relativeTime(lastActive)}' : ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            if (trustScore != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                TrustScoreGauge(trustScore.toDouble(), size: 24),
                const SizedBox(width: 8),
                Text('$approvedCount / $rejectedCount', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
