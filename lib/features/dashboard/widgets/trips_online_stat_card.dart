import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Single dashboard card combining "Trips Completed" and "Online Time",
/// replacing the two separate stat cards previously shown side by side.
class TripsOnlineStatCard extends StatelessWidget {
  const TripsOnlineStatCard({
    super.key,
    required this.tripsValue,
    required this.onlineTimeValue,
  });

  final String tripsValue;
  final String onlineTimeValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatSection(
              icon: Icons.work_outline_rounded,
              label: 'Trips Completed',
              value: tripsValue,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _StatSection(
              icon: Icons.schedule_rounded,
              label: 'Online Time',
              value: onlineTimeValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  const _StatSection({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
