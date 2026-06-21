import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/driver_transaction.dart';
import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final DriverTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amount >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconWell(
        icon: _iconFor(transaction.type),
        color: positive ? AppColors.primary : AppColors.danger,
        background: positive ? AppColors.primarySoft : AppColors.dangerSoft,
      ),
      title: Text(
        transaction.title,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
      ),
      trailing: Text(
        '${positive ? '+' : ''}${CurrencyFormatter.format(transaction.amount)}',
        style: TextStyle(
          color: positive ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
    'earning' => Icons.directions_car_rounded,
    'bonus' => Icons.card_giftcard_rounded,
    'withdrawal' => Icons.account_balance_wallet_rounded,
    _ => Icons.diamond_outlined,
  };
}
