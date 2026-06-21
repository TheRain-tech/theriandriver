import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    this.hint = 'Search',
    this.onChanged,
    this.onFilter,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: IconButton(
        onPressed: onFilter,
        icon: const Icon(Icons.tune_rounded, color: AppColors.slate),
      ),
    ),
  );
}
