import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// A single selectable card used by the taxonomy onboarding screens
/// (affiliation/region/services/vehicle category) - single or multi-select via [selected].
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
