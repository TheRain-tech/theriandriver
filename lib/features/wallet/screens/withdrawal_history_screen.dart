import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_transaction.dart';
import '../../../data/repositories/driver_wallet_repository.dart';
import '../../shared/widgets/feature_templates.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  final _repository = DriverWalletRepository();
  String _tab = 'All';

  @override
  Widget build(BuildContext context) => StreamBuilder<List<DriverTransaction>>(
    stream: _repository.watchTransactions(),
    builder: (context, snapshot) {
      final source = snapshot.data ?? const <DriverTransaction>[];
      final withdrawals = source
          .where((item) => item.type == 'withdrawal')
          .toList();
      final filtered = _tab == 'All'
          ? withdrawals
          : withdrawals
                .where(
                  (item) =>
                      item.status.name.toLowerCase() == _tab.toLowerCase(),
                )
                .toList();
      return FeatureScaffold(
        title: 'Withdrawal History',
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in ['All', 'Completed', 'Pending', 'Failed'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No withdrawal requests in this category.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final item in filtered) ...[
            AppCard(
              child: Row(
                children: [
                  const IconWell(icon: Icons.phone_android_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(item.amount.abs()),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(item.title),
                        Text(
                          '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: item.status.name,
                    tone: item.status == WithdrawalStatus.completed
                        ? BadgeTone.success
                        : item.status == WithdrawalStatus.pending
                        ? BadgeTone.warning
                        : BadgeTone.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}
