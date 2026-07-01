import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/driver_earning.dart';
import '../../../data/repositories/driver_earning_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/stat_card.dart';

class EarningsDashboardScreen extends StatefulWidget {
  const EarningsDashboardScreen({super.key});

  @override
  State<EarningsDashboardScreen> createState() =>
      _EarningsDashboardScreenState();
}

class _EarningsDashboardScreenState extends State<EarningsDashboardScreen> {
  final _repository = DriverEarningRepository();
  String _period = 'Weekly';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: DriverAppBar(
      title: 'Earnings',
      showLogo: false,
      actions: [
        IconButton(
          onPressed: () =>
              Navigator.pushNamed(context, RouteNames.notifications),
          icon: const Badge(child: Icon(Icons.notifications_outlined)),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: FutureBuilder<List<DriverEarning>>(
        future: _repository.getEarnings(period: _period),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'We could not load your earnings. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.danger),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final earningsList = snapshot.data ?? const [];
          final earning = earningsList.firstOrNull;
          if (earning == null) {
            return const Center(child: Text('No earnings data found.'));
          }

          final dailyEarnings = _period == 'Weekly' && earningsList.length >= 8
              ? earningsList.sublist(1, 8)
              : const <DriverEarning>[];

          double maxEarning = dailyEarnings.isNotEmpty
              ? dailyEarnings
                    .map((e) => e.total)
                    .fold(0.0, (max, val) => val > max ? val : max)
              : 0.0;
          if (maxEarning == 0) maxEarning = 1.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Daily', label: Text('Daily')),
                    ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                    ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (value) =>
                      setState(() => _period = value.first),
                ),
                const SizedBox(height: 18),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Earnings'),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(earning.total),
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '+12.5% from last week',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 190,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor:
                                                dailyEarnings.isNotEmpty
                                                ? (dailyEarnings[i].total > 0
                                                      ? (dailyEarnings[i]
                                                                    .total /
                                                                maxEarning)
                                                            .clamp(0.05, 1.0)
                                                      : 0.0)
                                                : 0.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        const [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun',
                                        ][i],
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                        icon: Icons.schedule_outlined,
                        label: 'Online Time',
                        value: _formatOnlineTime(earning.onlineMinutes),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StatCard(
                  icon: Icons.monetization_on_outlined,
                  label: 'Average per Trip',
                  value: CurrencyFormatter.format(
                    earning.tripCount == 0
                        ? 0
                        : earning.total / earning.tripCount,
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Row(
                    children: [
                      const IconWell(icon: Icons.card_giftcard_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledValue(
                          label: 'Bonuses this week',
                          value: CurrencyFormatter.format(earning.bonuses),
                        ),
                      ),
                      const Text(
                        '+8.3%',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.earningsSummary),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('View Payouts'),
                ),
              ],
            ),
          );
        },
      ),
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 1),
  );

  String _formatOnlineTime(int minutes) {
    if (minutes <= 0) return '0h 0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '${remainingMinutes}m';
    return '${hours}h ${remainingMinutes}m';
  }
}
