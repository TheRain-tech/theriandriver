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

  Color get color => switch (tone) {
    BadgeTone.success => AppColors.success,
    BadgeTone.warning => AppColors.warning,
    BadgeTone.danger => AppColors.danger,
    BadgeTone.info => AppColors.primary,
    BadgeTone.neutral => AppColors.slate,
  };

  Color get background => switch (tone) {
    BadgeTone.success => AppColors.successSoft,
    BadgeTone.warning => AppColors.warningSoft,
    BadgeTone.danger => AppColors.dangerSoft,
    BadgeTone.info => AppColors.primarySoft,
    BadgeTone.neutral => const Color(0xFFF0F3F7),
  };

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(width: 7),
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
