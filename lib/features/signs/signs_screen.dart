import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/theme_extensions.dart';
import '../../data/database/db_helper.dart';
import '../../data/models/category_model.dart';
import '../../data/models/fsl_sign_model.dart';
import '../../data/repositories/training_repository.dart';
import '../../shared/services/sign_translator.dart';
import '../../shared/services/catalog_notifier.dart';
import 'sign_detail_screen.dart';

Color _categoryColor(String name) {
  switch (name.toLowerCase()) {
    case 'alpabeto':
      return const Color(0xFF4CAF50);
    case 'mga karaniwang parirala':
      return const Color(0xFF2196F3);
    case 'mga bilang':
      return const Color(0xFFFF9800);
    case 'mga pangunahing galaw':
      return const Color(0xFFFF5722);
    default:
      return const Color(0xFF607D8B);
  }
}

class SignsScreen extends StatefulWidget {
  final void Function(int index)? onSwitchTab;

  const SignsScreen({super.key, this.onSwitchTab});

  @override
  State<SignsScreen> createState() => _SignsScreenState();
}

class _SignsScreenState extends State<SignsScreen> {
  final _searchController = TextEditingController();
  final _translator = SignTranslator();
  final _trainingRepo = TrainingRepository();

  List<CategoryModel> _categories = [];
  List<FslSignModel> _allSigns = [];
  List<FslSignModel> _filteredSigns = [];
  int? _selectedCategoryId;
  bool _loaded = false;
  final Map<int, int> _sampleCounts = {};
  final Map<int, int> _refCounts = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    CatalogNotifier.catalogCleared.addListener(_onReload);
    CatalogNotifier.trainingStatusChanged.addListener(_onReload);
  }

  @override
  void dispose() {
    _searchController.dispose();
    CatalogNotifier.catalogCleared.removeListener(_onReload);
    CatalogNotifier.trainingStatusChanged.removeListener(_onReload);
    super.dispose();
  }

  void _onReload() {
    _loaded = false;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadData();
      _loaded = true;
    }
  }

  Future<void> _loadData() async {
    final db = await DbHelper().database;

    final catMaps = await db.query('categories', orderBy: 'category_name ASC');
    final signMaps = await db.query('fsl_signs', orderBy: 'sign_name ASC');

    final sampleCounts = <int, int>{};
    final refCounts = <int, int>{};
    for (final sign in signMaps) {
      final signId = sign['id'] as int;
      final sampleRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM training_samples WHERE sign_id = ?',
        [signId],
      );
      sampleCounts[signId] = (sampleRes.first['cnt'] as int?) ?? 0;
      final refRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM reference_landmarks WHERE sign_id = ?',
        [signId],
      );
      refCounts[signId] = (refRes.first['cnt'] as int?) ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _categories = catMaps.map((m) => CategoryModel.fromMap(m)).toList();
      _allSigns = signMaps.map((m) => FslSignModel.fromMap(m)).toList();
      _sampleCounts
        ..clear()
        ..addAll(sampleCounts);
      _refCounts
        ..clear()
        ..addAll(refCounts);
      _filterSigns();
    });
  }

  void _onSearchChanged() {
    _filterSigns();
  }

  void _deleteSign(FslSignModel sign) async {
    final db = await DbHelper().database;
    await db
        .delete('training_samples', where: 'sign_id = ?', whereArgs: [sign.id]);
    await db.delete('sign_media', where: 'sign_id = ?', whereArgs: [sign.id]);
    await db.delete('fsl_signs', where: 'id = ?', whereArgs: [sign.id]);
    _allSigns.removeWhere((s) => s.id == sign.id);
    _filterSigns();
  }

  void _filterSigns() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredSigns = _allSigns.where((s) {
        final matchesCategory =
            _selectedCategoryId == null || s.categoryId == _selectedCategoryId;
        final matchesSearch =
            query.isEmpty || s.signName.toLowerCase().contains(query);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId =
          _selectedCategoryId == categoryId ? null : categoryId;
      _filterSigns();
    });
  }

  String _categoryName(int? categoryId) {
    if (categoryId == null) return '';
    return _categories
            .where((c) => c.id == categoryId)
            .map((c) => c.categoryName)
            .firstOrNull ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signs')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          Expanded(child: _buildSignGrid()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSignDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddSignDialog() async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    int? selectedCatId = _categories.isNotEmpty ? _categories.first.id : null;

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
                  value: selectedCatId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.categoryName)))
                      .toList(),
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

    if (saved == true && mounted) {
      final name = nameCtl.text.trim();
      if (name.isEmpty) return;

      final db = await DbHelper().database;
      await db.insert('fsl_signs', {
        'sign_name': name,
        'description': descCtl.text.trim(),
        'category_id': selectedCatId,
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" added')),
        );
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search signs...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _buildChip('All', null),
          ..._categories
              .map((c) => _buildChip(_translator.categoryName(c), c.id)),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int? categoryId) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectCategory(categoryId),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : context.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSignGrid() {
    if (_allSigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pan_tool, size: 64, color: context.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No signs loaded',
              style: TextStyle(
                fontSize: 18,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Run the app to seed the database',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredSigns.isEmpty) {
      return Center(
        child: Text(
          'No signs match your search',
          style: TextStyle(
            fontSize: 16,
            color: context.textSecondary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _filteredSigns.length,
        itemBuilder: (context, index) {
          final sign = _filteredSigns[index];
          return Dismissible(
            key: ValueKey(sign.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete "${_translator.signName(sign)}"?'),
                  content: const Text('This sign will be permanently deleted.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Delete',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  ],
                ),
              );
              return confirm ?? false;
            },
            onDismissed: (_) => _deleteSign(sign),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: _buildSignCard(sign),
          );
        },
      ),
    );
  }

  Widget _buildSignCard(FslSignModel sign) {
    final filipinoCatName = _categoryName(sign.categoryId);
    final catColor = _categoryColor(filipinoCatName);
    final catModel = sign.categoryId != null
        ? _categories.where((c) => c.id == sign.categoryId).firstOrNull
        : null;
    final catDisplay =
        catModel != null ? _translator.categoryName(catModel) : filipinoCatName;
    final displayName = _translator.signName(sign);
    final displayDesc = _translator.signDescription(sign);
    final sampleCount = _sampleCounts[sign.id] ?? 0;
    final refCount = _refCounts[sign.id] ?? 0;
    final isTrained = sign.trainingStatus == 'trained' ||
        refCount >= TrainingRepository.minSamplesForTrained;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SignDetailScreen(
                sign: sign,
                categoryName: filipinoCatName,
                onPractice: () {
                  Navigator.pop(context);
                  widget.onSwitchTab?.call(1);
                },
              ),
            ),
          );
          if (mounted) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (catDisplay.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          catDisplay,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isTrained
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isTrained ? 'Practice' : 'Train',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isTrained
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      catColor.withValues(alpha: 0.2),
                      catColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: catColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (displayDesc.isNotEmpty)
                Text(
                  displayDesc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
