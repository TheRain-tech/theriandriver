import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/driver_earning.dart';
import '../../../data/repositories/driver_earning_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/stat_card.dart';

class EarningsSummaryScreen extends StatelessWidget {
  EarningsSummaryScreen({super.key});
  final _repository = DriverEarningRepository();

  String _formatOnlineTime(int minutes) {
    if (minutes <= 0) return '0h 0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '${remainingMinutes}m';
    return '${hours}h ${remainingMinutes}m';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DriverEarning>>(
    future: _repository.getEarnings(),
    builder: (context, snapshot) {
      final earning = snapshot.data?.first;
      if (earning == null) {
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final copy = DriverCopy.of(context);
      return FeatureScaffold(
        title: copy.t('Earnings Summary', 'Résumé des revenus'),
        children: [
          DropdownButtonFormField<String>(
            initialValue: 'May 2026',
            items: [
              DropdownMenuItem(
                value: 'May 2026',
                child: Text(copy.t('May 2026', 'Mai 2026')),
              ),
              DropdownMenuItem(
                value: 'April 2026',
                child: Text(copy.t('April 2026', 'Avril 2026')),
              ),
            ],
            onChanged: (_) {},
          ),
          SizedBox(height: 24),
          Text(copy.t('Total Earnings', 'Revenus totaux'), textAlign: TextAlign.center),
          Text(
            CurrencyFormatter.format(earning.total),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.work_outline_rounded,
                  label: copy.t('Trips', 'Courses'),
                  value: '${earning.tripCount}',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  icon: Icons.schedule_rounded,
                  label: copy.t('Online', 'En ligne'),
                  value: _formatOnlineTime(earning.onlineMinutes),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('Earnings Breakdown', 'Détail des revenus'),
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 14),
                _line(context, copy.t('Base Fare', 'Tarif de base'), earning.baseFares),
                _line(context, copy.t('Bonuses', 'Bonus'), earning.bonuses),
                _line(context, copy.t('Tips', 'Pourboires'), earning.tips),
                _line(
                  context,
                  copy.t('Deductions', 'Déductions'),
                  -earning.deductions,
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          OutlinedButton(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.withdrawalHistory),
            child: Text(copy.t('View Transactions', 'Voir les transactions')),
          ),
        ],
      );
    },
  );

  Widget _line(
    BuildContext context,
    String label,
    double amount, {
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
            color: color ?? AppColors.textPrimaryFor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
