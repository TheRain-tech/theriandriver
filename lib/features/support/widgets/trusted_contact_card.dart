import 'package:flutter/material.dart';

import '../../../data/models/trusted_contact.dart';
import '../../../theme/app_colors.dart';

/// A filled trusted-contact row with call/delete actions.
class TrustedContactCard extends StatelessWidget {
  const TrustedContactCard({
    super.key,
    required this.contact,
    required this.onCall,
    required this.onDelete,
  });

  final TrustedContact contact;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.24 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
            child: const Icon(Icons.person_rounded, color: AppColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phoneNumber,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: const Icon(Icons.phone_rounded, color: AppColors.success),
            tooltip: 'Call ${contact.name}',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            tooltip: 'Remove ${contact.name}',
          ),
        ],
      ),
    );
  }
}

/// An empty "Add Contact" slot with a dashed border.
class AddContactCard extends StatelessWidget {
  const AddContactCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.borderFor(context),
          radius: 12,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: AppColors.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add Contact',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  final double strokeWidth = 1.4;
  final double dashWidth = 6;
  final double gapWidth = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
