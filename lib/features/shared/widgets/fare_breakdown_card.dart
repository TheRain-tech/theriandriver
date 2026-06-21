import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

class FareBreakdownCard extends StatelessWidget {
  const FareBreakdownCard({
    super.key,
    required this.baseFare,
    required this.bonus,
    required this.tip,
    this.deductions = 0,
  });

  final double baseFare;
  final double bonus;
  final double tip;
  final double deductions;

  @override
  Widget build(BuildContext context) {
    final total = baseFare + bonus + tip - deductions;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fare Breakdown',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _row('Base Fare', baseFare),
          _row('Bonus', bonus, color: AppColors.success),
          _row('Tip', tip, color: AppColors.success),
          if (deductions > 0)
            _row('Deductions', -deductions, color: AppColors.danger),
          const Divider(height: 28),
          _row('Total Earnings', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value, {
    Color color = AppColors.navy,
    bool isTotal = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            color: color,
            fontSize: isTotal ? 22 : 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
