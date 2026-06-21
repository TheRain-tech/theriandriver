import 'package:flutter/material.dart';

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
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FeatureScaffold(
        title: 'Earnings Summary',
        children: [
          DropdownButtonFormField<String>(
            initialValue: 'May 2026',
            items: const [
              DropdownMenuItem(value: 'May 2026', child: Text('May 2026')),
              DropdownMenuItem(value: 'April 2026', child: Text('April 2026')),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 24),
          const Text('Total Earnings', textAlign: TextAlign.center),
          Text(
            CurrencyFormatter.format(earning.total),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.work_outline_rounded,
                  label: 'Trips',
                  value: '${earning.tripCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  icon: Icons.schedule_rounded,
                  label: 'Online',
                  value: _formatOnlineTime(earning.onlineMinutes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Earnings Breakdown',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 14),
                _line('Base Fare', earning.baseFares),
                _line('Bonuses', earning.bonuses),
                _line('Tips', earning.tips),
                _line(
                  'Deductions',
                  -earning.deductions,
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, RouteNames.withdrawalHistory),
            child: const Text('View Transactions'),
          ),
        ],
      );
    },
  );

  Widget _line(String label, double amount, {Color color = AppColors.navy}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}
