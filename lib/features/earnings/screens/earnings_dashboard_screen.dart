import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/driver_earning.dart';
import '../../../data/models/revenue_summary.dart';
import '../../../data/models/revenue_transaction.dart';
import '../../../data/repositories/driver_earning_repository.dart';
import '../../../data/repositories/driver_revenue_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/search_filter_bar.dart';
import '../../shared/widgets/stat_card.dart';

class EarningsDashboardScreen extends StatefulWidget {
  const EarningsDashboardScreen({super.key});

  @override
  State<EarningsDashboardScreen> createState() =>
      _EarningsDashboardScreenState();
}

class _EarningsDashboardScreenState extends State<EarningsDashboardScreen> {
  final _repository = DriverEarningRepository();
  final _revenueRepository = DriverRevenueRepository();
  String _period = 'Weekly';
  DateTimeRange? _customDateRange;
  late Future<List<DriverEarning>> _earningsFuture;
  late Future<_RevenueOverview> _revenueFuture;

  @override
  void initState() {
    super.initState();
    _reloadEarnings();
    _revenueFuture = _loadRevenueOverview();
  }

  void _reloadEarnings() {
    _earningsFuture = _repository.getEarnings(
      period: _period,
      dateRange: _customDateRange,
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day - 6),
            end: now,
          ),
      helpText: 'Select earnings dates',
      saveText: 'Apply range',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customDateRange = selected;
      _reloadEarnings();
    });
  }

  String _customDateRangeLabel() {
    final range = _customDateRange;
    if (range == null) return 'Custom date range';
    return '${DateFormatter.short(range.start)} - ${DateFormatter.short(range.end)}';
  }

  Future<_RevenueOverview> _loadRevenueOverview() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) {
      return const _RevenueOverview(summary: RevenueSummary.empty, recent: []);
    }
    final fleetName = DriverProfileService.instance.profile.value.fleetName;
    final results = await Future.wait([
      _revenueRepository.getSummary(uid),
      _revenueRepository.getTransactions(uid, fleetName: fleetName),
    ]);
    return _RevenueOverview(
      summary: results[0] as RevenueSummary,
      recent: (results[1] as List<RevenueTransaction>).take(5).toList(),
    );
  }

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
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'We could not load your earnings. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.danger),
                    ),
                    SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => setState(_reloadEarnings),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final earningsList = snapshot.data ?? const [];
          final earning = earningsList.firstOrNull;
          if (earning == null) {
            return Center(child: Text('No earnings data found.'));
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
                    ButtonSegment(value: 'Daily', label: Text('Today')),
                    ButtonSegment(value: 'Weekly', label: Text('This Week')),
                    ButtonSegment(value: 'Monthly', label: Text('This Month')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (value) => setState(() {
                    _period = value.first;
                    _customDateRange = null;
                    _reloadEarnings();
                  }),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickCustomDateRange,
                        icon: Icon(Icons.date_range_rounded),
                        label: Text(
                          _customDateRangeLabel(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_customDateRange != null) ...[
                      SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Clear custom dates',
                        onPressed: () => setState(() {
                          _customDateRange = null;
                          _reloadEarnings();
                        }),
                        icon: Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 18),
                // Bolt-style hero card: one large, unmissable total-earnings number on a solid
                // brand-color background, with the trip stats folded in underneath instead of
                // scattered across separate cards.
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customDateRange == null
                            ? 'Total Earnings'
                            : 'Earnings for selected dates',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(earning.total),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              label: 'Trips',
                              value: '${earning.tripCount}',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: _HeroStat(
                              label: 'Online',
                              value: _formatOnlineTime(earning.onlineMinutes),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: _HeroStat(
                              label: 'Per Trip',
                              value: CurrencyFormatter.format(
                                earning.tripCount == 0
                                    ? 0
                                    : earning.total / earning.tripCount,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (dailyEarnings.isNotEmpty) ...[
                  SizedBox(height: 14),
                  AppCard(
                    child: SizedBox(
                      height: 170,
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
                                              dailyEarnings[i].total > 0
                                              ? (dailyEarnings[i].total /
                                                        maxEarning)
                                                    .clamp(0.05, 1.0)
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
                                    SizedBox(height: 7),
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
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.earningsSummary),
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: Text('View Payouts'),
                ),
                SizedBox(height: 28),
                const SectionHeader(title: 'TheRain Revenue'),
                SizedBox(height: 10),
                _RevenueOverviewSection(future: _revenueFuture),
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

class _RevenueOverview {
  const _RevenueOverview({required this.summary, required this.recent});

  final RevenueSummary summary;
  final List<RevenueTransaction> recent;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}

/// Today's/Weekly/Monthly/Total Lifetime Earnings summary + Recent
/// Transactions + Search/Filter/Export — wired to node-api's real
/// driver-payroll/fleet-reports endpoints (server-computed from the
/// driver's actual RIDE_EARNINGS wallet transactions), additive to the
/// existing Earnings dashboard rather than replacing it.
class _RevenueOverviewSection extends StatefulWidget {
  const _RevenueOverviewSection({required this.future});

  final Future<_RevenueOverview> future;

  @override
  State<_RevenueOverviewSection> createState() =>
      _RevenueOverviewSectionState();
}

class _RevenueOverviewSectionState extends State<_RevenueOverviewSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) => FutureBuilder<_RevenueOverview>(
    future: widget.future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return AppCard(
          child: Column(
            children: [
              Text(
                'We could not load your TheRain revenue right now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.danger),
              ),
              SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  RouteNames.earnings,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }

      final overview = snapshot.data;
      final summary = overview?.summary ?? RevenueSummary.empty;
      final recent = overview?.recent ?? const <RevenueTransaction>[];
      final query = _query.trim().toLowerCase();
      final filteredRecent = query.isEmpty
          ? recent
          : recent
                .where(
                  (row) =>
                      (row.rideId ?? '').toLowerCase().contains(query) ||
                      row.driverEarnings.toStringAsFixed(0).contains(query),
                )
                .toList();

      final isFleetDriver =
          DriverProfileService.instance.profile.value.isFleetDriver;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.today_rounded,
                  label: "Today's Earnings",
                  value: CurrencyFormatter.format(summary.today),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  icon: Icons.date_range_rounded,
                  label: 'This Week',
                  value: CurrencyFormatter.format(summary.thisWeek),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'This Month',
                  value: CurrencyFormatter.format(summary.thisMonth),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  icon: Icons.savings_rounded,
                  label: 'Lifetime Earnings',
                  value: CurrencyFormatter.format(summary.allTime),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SearchFilterBar(
                  hint: 'Search recent transactions',
                  onChanged: (value) => setState(() => _query = value),
                  onFilter: () =>
                      Navigator.pushNamed(context, RouteNames.revenueHistory),
                ),
              ),
              SizedBox(width: 8),
              // Export is not wired to a real generator yet — a queued/disabled
              // stub rather than a fake working export, per spec.
              Tooltip(
                message: 'Export is coming soon',
                child: IconButton.filledTonal(
                  onPressed: null,
                  icon: Icon(Icons.ios_share_rounded),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          if (filteredRecent.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No recent transactions yet.')),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < filteredRecent.length; i++) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: IconWell(
                        icon: Icons.payments_rounded,
                        color: AppColors.success,
                        background: AppColors.successSoftFor(context),
                      ),
                      title: Text(
                        filteredRecent[i].rideId == null
                            ? 'Trip earnings'
                            : 'Trip #${filteredRecent[i].rideId}',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${DateFormatter.short(filteredRecent[i].date)} • '
                        '${filteredRecent[i].paymentMethod ?? 'Digital'}',
                      ),
                      trailing: Text(
                        '+${CurrencyFormatter.format(filteredRecent[i].driverEarnings)}',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (i < filteredRecent.length - 1) Divider(height: 1),
                  ],
                ],
              ),
            ),
          SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.revenueHistory),
            icon: Icon(Icons.history_rounded),
            label: Text('View Full Revenue History'),
          ),
          if (!isFleetDriver) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, RouteNames.paymentRequest),
                    icon: Icon(Icons.request_quote_rounded),
                    label: Text('Request Payment'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, RouteNames.paymentHistory),
                    icon: Icon(Icons.receipt_long_rounded),
                    label: Text('Payment History'),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}
