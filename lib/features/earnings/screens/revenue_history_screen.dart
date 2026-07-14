import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/revenue_transaction.dart';
import '../../../data/repositories/driver_revenue_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/search_filter_bar.dart';

enum _RevenueRange { today, week, month, year }

/// Revenue History: Trip ID, Date, Amount, Payment Method, Status, Fleet
/// Name, Driver Earnings — filterable by Today/Week/Month/Year, searchable
/// by Ride ID/Amount/Date. Real data from node-api (driver-payroll wallet
/// transactions joined with the matching ride).
class RevenueHistoryScreen extends StatefulWidget {
  const RevenueHistoryScreen({super.key});

  @override
  State<RevenueHistoryScreen> createState() => _RevenueHistoryScreenState();
}

class _RevenueHistoryScreenState extends State<RevenueHistoryScreen> {
  final _repository = DriverRevenueRepository();
  late Future<List<RevenueTransaction>> _future;
  _RevenueRange _range = _RevenueRange.month;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RevenueTransaction>> _load() {
    final uid = AuthService.instance.currentUserId ?? '';
    final fleetName = DriverProfileService.instance.profile.value.fleetName;
    if (uid.isEmpty) return Future.value(const []);
    return _repository.getTransactions(uid, fleetName: fleetName);
  }

  bool _withinRange(DateTime date) {
    final now = DateTime.now();
    switch (_range) {
      case _RevenueRange.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case _RevenueRange.week:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return !date.isBefore(startOfWeek);
      case _RevenueRange.month:
        return date.year == now.year && date.month == now.month;
      case _RevenueRange.year:
        return date.year == now.year;
    }
  }

  List<RevenueTransaction> _filter(List<RevenueTransaction> rows) {
    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      if (!_withinRange(row.date)) return false;
      if (query.isEmpty) return true;
      return (row.rideId ?? '').toLowerCase().contains(query) ||
          row.driverEarnings.toStringAsFixed(0).contains(query) ||
          DateFormatter.short(row.date).toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Revenue History',
    children: [
      SearchFilterBar(
        hint: 'Search by Ride ID, amount, or date',
        onChanged: (value) => setState(() => _query = value),
        onFilter: () {},
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final range in _RevenueRange.values) ...[
              ChoiceChip(
                label: Text(_rangeLabel(range)),
                selected: _range == range,
                onSelected: (_) => setState(() => _range = range),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<RevenueTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _errorState(() => setState(() => _future = _load()));
          }
          final rows = _filter(snapshot.data ?? const []);
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No transactions found for this period.'),
              ),
            );
          }
          return Column(
            children: [
              for (final row in rows) ...[_TransactionCard(row: row)],
            ],
          );
        },
      ),
    ],
  );

  Widget _errorState(VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const Text(
          'We could not load your revenue history. Please try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.danger),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );

  String _rangeLabel(_RevenueRange range) => switch (range) {
    _RevenueRange.today => 'Today',
    _RevenueRange.week => 'Week',
    _RevenueRange.month => 'Month',
    _RevenueRange.year => 'Year',
  };
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.row});

  final RevenueTransaction row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.rideId == null
                      ? 'Trip earnings'
                      : 'Trip #${row.rideId}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: _statusLabel(row.status),
                tone: _statusTone(row.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormatter.short(row.date)} • ${DateFormatter.time(row.date)}',
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: 'Driver Earnings',
                  value: CurrencyFormatter.format(row.driverEarnings),
                  valueColor: AppColors.success,
                ),
              ),
              Expanded(
                child: LabeledValue(
                  label: 'Trip Amount',
                  value: row.tripAmount == null
                      ? '—'
                      : CurrencyFormatter.format(row.tripAmount!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: 'Payment Method',
                  value: row.paymentMethod ?? '—',
                ),
              ),
              Expanded(
                child: LabeledValue(
                  label: 'Fleet',
                  value: row.fleetName ?? 'TheRain Direct',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _statusLabel(String? status) {
    final normalized = (status ?? 'completed').toLowerCase();
    if (normalized.contains('cancel')) return 'Cancelled';
    if (normalized == 'completed') return 'Completed';
    return normalized.isEmpty ? 'Completed' : normalized;
  }

  BadgeTone _statusTone(String? status) {
    final normalized = (status ?? 'completed').toLowerCase();
    if (normalized.contains('cancel')) return BadgeTone.danger;
    return BadgeTone.success;
  }
}
