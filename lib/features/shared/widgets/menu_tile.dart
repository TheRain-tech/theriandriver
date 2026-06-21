import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    onTap: onTap,
    leading: IconWell(
      icon: icon,
      color: danger ? AppColors.danger : AppColors.primary,
      background: danger ? AppColors.dangerSoft : AppColors.primarySoft,
      size: 42,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: danger ? AppColors.danger : AppColors.navy,
        fontWeight: FontWeight.w600,
      ),
    ),
    trailing:
        trailing ??
        const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
  );
}
