import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
    final copy = DriverCopy.of(context);
    final total = baseFare + bonus + tip - deductions;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('Fare Breakdown', 'Détail du tarif'),
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          _row(context, copy.t('Base Fare', 'Tarif de base'), baseFare),
          _row(
            context,
            copy.t('Bonus', 'Bonus'),
            bonus,
            color: AppColors.success,
          ),
          _row(context, copy.t('Tip', 'Pourboire'), tip, color: AppColors.success),
          if (deductions > 0)
            _row(
              context,
              copy.t('Deductions', 'Déductions'),
              -deductions,
              color: AppColors.danger,
            ),
          Divider(height: 28),
          _row(
            context,
            copy.t('Total Earnings', 'Revenus totaux'),
            total,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double value, {
    Color? color,
    bool isTotal = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            color: color ?? AppColors.textPrimaryFor(context),
            fontSize: isTotal ? 22 : 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
