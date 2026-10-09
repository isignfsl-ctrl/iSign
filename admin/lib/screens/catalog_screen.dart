import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isign_shared/isign_shared.dart';
import '../services/admin_firebase_service.dart';
import '../services/admin_auth_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loader.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _fb = AdminFirebaseService();
  final _auth = AdminAuthService();
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _sortAscending = true;
  int _sortColumnIndex = 0;

  @override
  void dispose() { _debounce?.cancel(); _searchCtl.dispose(); super.dispose(); }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = v.toLowerCase());
    });
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() { _sortColumnIndex = columnIndex; _sortAscending = ascending; });
  }

  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      final aD = a.data() as Map<String, dynamic>;
      final bD = b.data() as Map<String, dynamic>;
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = (aD['signId'] as int? ?? 0).compareTo(bD['signId'] as int? ?? 0); break;
        case 1: cmp = ((aD['signName'] as String? ?? '')).compareTo(bD['signName'] as String? ?? ''); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return docs;
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

  Future<void> _addOrEditEntry({SignCatalogEntry? existing}) async {
    final nameCtl = TextEditingController(text: existing?.signName ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final idCtl = TextEditingController(text: existing?.signId.toString() ?? '');
    int selectedCat = existing?.categoryId ?? 0;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(existing != null ? 'Edit Sign' : 'Add Sign', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(controller: idCtl, decoration: const InputDecoration(labelText: 'Sign ID', helperText: 'Numeric identifier'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Sign Name'), textInputAction: TextInputAction.next),
                  const SizedBox(height: 12),
                  TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description', helperText: 'Brief description of the sign'), maxLines: 3),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCat,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(_categoryName(0))),
                      DropdownMenuItem(value: 1, child: Text(_categoryName(1))),
                      DropdownMenuItem(value: 2, child: Text(_categoryName(2))),
                      DropdownMenuItem(value: 3, child: Text(_categoryName(3))),
                    ],
                    onChanged: (v) => setSheetState(() => selectedCat = v ?? 0),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save'))),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      final name = nameCtl.text.trim();
      final desc = descCtl.text.trim();
      final id = int.tryParse(idCtl.text.trim()) ?? 0;
      final user = _auth.currentUser;
      if (name.isEmpty) return;

      final data = {
        'signId': id, 'signName': name, 'description': desc, 'categoryId': selectedCat,
        'version': (existing?.version ?? 0) + 1,
        'landmarkSamplePaths': existing?.landmarkSamplePaths ?? [],
        'updatedAt': DateTime.now().toIso8601String(), 'updatedBy': user?.email ?? 'admin',
      };

      if (existing != null) {
        final docs = await _fb.firestore.collection('catalog').where('signId', isEqualTo: id).limit(1).get();
        if (docs.docs.isNotEmpty) {
          await _fb.firestore.collection('catalog').doc(docs.docs.first.id).update(data);
        }
      } else {
        await _fb.firestore.collection('catalog').add(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(existing != null ? 'Updated "$name"' : 'Added "$name"'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteEntry(BuildContext context, String docId, String signName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: Theme.of(ctx).colorScheme.error, size: 24), const SizedBox(width: 8), const Text('Delete entry?')]),
        content: Text('Are you sure you want to delete "$signName"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _fb.firestore.collection('catalog').doc(docId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted "$signName"'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Catalog'),
        actions: [IconButton(icon: const Icon(Icons.add), tooltip: 'Add sign', onPressed: () => _addOrEditEntry())],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtl, onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or ID...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtl.clear(); _onSearchChanged(''); })
                    : null,
                isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _fb.firestore.collection('catalog').orderBy('signId').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonCard(height: 60, lineCount: 1))),
                  );
                }

                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['signName'] as String? ?? '').toLowerCase();
                    final id = (data['signId'] as int? ?? 0).toString();
                    return name.contains(_searchQuery) || id.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return snapshot.data!.docs.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.book_outlined, title: 'No catalog entries.',
                          action: FilledButton.icon(onPressed: () => _addOrEditEntry(), icon: const Icon(Icons.add), label: const Text('Add First Sign')),
                        )
                      : const EmptyStateWidget(icon: Icons.search_off, title: 'No entries match your search.');
                }

                docs = _sortDocs(docs);
                final isWide = MediaQuery.of(context).size.width > 800;

                if (isWide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex, sortAscending: _sortAscending,
                      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerLow),
                      columns: [
                        DataColumn(label: const Text('ID'), onSort: _sort, numeric: true),
                        DataColumn(label: const Text('Name'), onSort: _sort),
                        const DataColumn(label: Text('Description')),
                        const DataColumn(label: Text('Cat')),
                        const DataColumn(label: Text('Samples')),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Version')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: docs.asMap().entries.map((entry) {
                        final data = entry.value.data() as Map<String, dynamic>;
                        final signEntry = SignCatalogEntry.fromFirestore(data);
                        final isEven = entry.key.isEven;
                        final approvedCount = (data['approvedSampleCount'] as int? ?? 0);
                        final totalSamplePaths = (data['landmarkSamplePaths'] as List<dynamic>?)?.length ?? 0;
                        final isTrained = approvedCount >= 5;
                        return DataRow(
                          color: isEven ? WidgetStateProperty.all(theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3)) : null,
                          cells: [
                            DataCell(Text(signEntry.signId.toString())),
                            DataCell(Text(signEntry.signName)),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(signEntry.description.isNotEmpty ? signEntry.description : '\u2014', overflow: TextOverflow.ellipsis, style: signEntry.description.isEmpty ? TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)) : null),
                            )),
                            DataCell(Text(_categoryName(signEntry.categoryId))),
                            DataCell(Text('$approvedCount/$totalSamplePaths')),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isTrained ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isTrained ? 'Trained' : 'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isTrained ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            )),
                            DataCell(Text(signEntry.version.toString())),
                            DataCell(Row(children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _addOrEditEntry(existing: signEntry)),
                              IconButton(icon: Icon(Icons.delete, size: 20, color: theme.colorScheme.error), onPressed: () => _deleteEntry(context, entry.value.id, signEntry.signName)),
                            ])),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final entry = SignCatalogEntry.fromFirestore(data);
                    final approvedCount = (data['approvedSampleCount'] as int? ?? 0);
                    final totalPaths = (data['landmarkSamplePaths'] as List<dynamic>?)?.length ?? 0;
                    final isTrained = approvedCount >= 5;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${entry.signId}. ${entry.signName}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_categoryName(entry.categoryId)} — ${entry.description.isNotEmpty ? entry.description : 'No description'}', style: entry.description.isNotEmpty ? theme.textTheme.bodySmall : theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('Approved: $approvedCount/$totalPaths', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isTrained ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isTrained ? 'Trained' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isTrained ? Colors.green.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditEntry(existing: entry), tooltip: 'Edit'),
                          IconButton(icon: Icon(Icons.delete, color: theme.colorScheme.error), onPressed: () => _deleteEntry(context, docs[index].id, entry.signName), tooltip: 'Delete'),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
