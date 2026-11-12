import 'package:flutter/material.dart';

import '../../data/database/db_helper.dart';
import '../../shared/services/catalog_notifier.dart';

/// Shows the "Add New Sign" dialog — the same flow as the Signs tab's
/// floating action button, shared so the speech-mode tutorial strip can
/// offer it too when a spoken word is not a registered sign yet.
///
/// [initialName] prefills the Sign Name field (used when the dialog is
/// opened from a specific unrecognized word).
///
/// Returns the saved sign name, or null when cancelled / invalid.
Future<String?> showAddSignDialog(
  BuildContext context, {
  String initialName = '',
}) async {
  final nameCtl = TextEditingController(text: initialName);
  final descCtl = TextEditingController();

  // Categories are loaded here rather than passed in so any caller can
  // open the dialog without preparing state first.
  final db = await DbHelper().database;
  final catMaps = await db.query('categories', orderBy: 'category_name ASC');
  final categories = <(int, String)>[
    for (final m in catMaps)
      (m['id'] as int, m['category_name'] as String? ?? ''),
  ];
  int? selectedCatId = categories.isNotEmpty ? categories.first.$1 : null;

  if (!context.mounted) return null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Add New Sign'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                      labelText: 'Sign Name', hintText: 'e.g. Salamat')),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe the gesture'),
                  maxLines: 3),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: selectedCatId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final (id, name) in categories)
                    DropdownMenuItem(value: id, child: Text(name)),
                ],
                onChanged: (v) => setDialogState(() => selectedCatId = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    ),
  );

  if (saved != true) return null;
  final name = nameCtl.text.trim();
  final description = descCtl.text.trim();
  nameCtl.dispose();
  descCtl.dispose();
  if (name.isEmpty) return null;

  await db.insert('fsl_signs', {
    'sign_name': name,
    'description': description,
    'category_id': selectedCatId,
  });
  // Tell every catalog listener (Signs tab, translator, …) to reload so
  // the new sign shows up immediately everywhere.
  CatalogNotifier.catalogCleared.value++;
  return name;
}
