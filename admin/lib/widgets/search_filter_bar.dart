import 'package:flutter/material.dart';

class SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final List<FilterChipOption>? filterOptions;
  final String? selectedFilter;
  final ValueChanged<String?>? onFilterChanged;

  const SearchFilterBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    required this.onChanged,
    this.filterOptions,
    this.selectedFilter,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (filterOptions != null && filterOptions!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: filterOptions!.map((opt) {
              final selected = selectedFilter == opt.value;
              return FilterChip(
                label: Text(opt.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                selected: selected,
                onSelected: (_) => onFilterChanged?.call(selected ? null : opt.value),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class FilterChipOption {
  final String label;
  final String value;
  const FilterChipOption(this.label, this.value);
}
