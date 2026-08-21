import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        IconWell(icon: icon, size: 42),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    if (suffix != null)
                      TextSpan(
                        text: ' $suffix',
                        style: TextStyle(
                          color: AppColors.textSecondaryFor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
