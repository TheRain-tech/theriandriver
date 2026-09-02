import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum BadgeTone { success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.success,
    this.showDot = true,
  });

  final String label;
  final BadgeTone tone;
  final bool showDot;

  Color colorFor(BuildContext context) => switch (tone) {
    BadgeTone.success => AppColors.success,
    BadgeTone.warning => AppColors.warning,
    BadgeTone.danger => AppColors.danger,
    BadgeTone.info => AppColors.primary,
    BadgeTone.neutral => AppColors.textSecondaryFor(context),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context);
    final background = switch (tone) {
      BadgeTone.success => AppColors.successSoftFor(context),
      BadgeTone.warning => AppColors.warningSoftFor(context),
      BadgeTone.danger => AppColors.dangerSoftFor(context),
      BadgeTone.info => AppColors.primarySoftFor(context),
      BadgeTone.neutral =>
        AppColors.isDark(context)
            ? AppColors.darkElevatedSurface
            : const Color(0xFFF0F3F7),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
