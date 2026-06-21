import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

class TripRouteCard extends StatelessWidget {
  const TripRouteCard({
    super.key,
    required this.pickup,
    required this.dropOff,
    this.pickupLabel = 'Pickup',
    this.dropOffLabel = 'Drop-off',
  });

  final String pickup;
  final String dropOff;
  final String pickupLabel;
  final String dropOffLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        _Stop(
          color: AppColors.primary,
          label: pickupLabel,
          value: pickup,
          isLast: false,
        ),
        _Stop(
          color: AppColors.success,
          label: dropOffLabel,
          value: dropOff,
          isLast: true,
        ),
      ],
    ),
  );
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.color,
    required this.label,
    required this.value,
    required this.isLast,
  });
  final Color color;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 26,
        child: Column(
          children: [
            Icon(Icons.location_on, color: color, size: 25),
            if (!isLast)
              Container(height: 37, width: 2, color: AppColors.border),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
