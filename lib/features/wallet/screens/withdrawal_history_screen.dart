import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
      final copy = DriverCopy.of(context);
      String tabLabel(String tab) => switch (tab) {
        'Completed' => copy.t('Completed', 'Terminées'),
        'Pending' => copy.t('Pending', 'En attente'),
        'Failed' => copy.t('Failed', 'Échouées'),
        _ => copy.t('All', 'Toutes'),
      };
      String statusLabel(WithdrawalStatus status) => switch (status) {
        WithdrawalStatus.completed => copy.t('Completed', 'Terminé'),
        WithdrawalStatus.pending => copy.t('Pending', 'En attente'),
        WithdrawalStatus.failed => copy.t('Failed', 'Échoué'),
      };
      return FeatureScaffold(
        title: copy.t('Withdrawal History', 'Historique des retraits'),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in ['All', 'Completed', 'Pending', 'Failed'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tabLabel(tab)),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                copy.t(
                  'No withdrawal requests in this category.',
                  'Aucune demande de retrait dans cette catégorie.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          for (final item in filtered) ...[
            AppCard(
              child: Row(
                children: [
                  IconWell(icon: Icons.phone_android_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(item.amount.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(item.title),
                        Text(
                          '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: statusLabel(item.status),
                    tone: item.status == WithdrawalStatus.completed
                        ? BadgeTone.success
                        : item.status == WithdrawalStatus.pending
                        ? BadgeTone.warning
                        : BadgeTone.danger,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}
