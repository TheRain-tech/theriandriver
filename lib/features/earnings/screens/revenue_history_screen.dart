import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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

enum _RevenueRange { today, week, month, year, custom }

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
  DateTimeRange? _customDateRange;
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
    final range = _selectedDateRange();
    return _repository.getTransactions(
      uid,
      fleetName: fleetName,
      from: range?.start,
      to: range?.end,
    );
  }

  DateTimeRange? _selectedDateRange() {
    final now = DateTime.now();
    switch (_range) {
      case _RevenueRange.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case _RevenueRange.week:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: startOfWeek, end: now);
      case _RevenueRange.month:
        return DateTimeRange(start: DateTime(now.year, now.month), end: now);
      case _RevenueRange.year:
        return DateTimeRange(start: DateTime(now.year), end: now);
      case _RevenueRange.custom:
        return _customDateRange;
    }
  }

  Future<void> _pickCustomRange() async {
    final copy = DriverCopy.of(context);
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
      helpText: copy.t('Select revenue dates', 'Sélectionner la période'),
      saveText: copy.t('Apply range', 'Appliquer'),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _range = _RevenueRange.custom;
      _customDateRange = selected;
      _future = _load();
    });
  }

  List<RevenueTransaction> _filter(List<RevenueTransaction> rows) {
    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      if (query.isEmpty) return true;
      return (row.rideId ?? '').toLowerCase().contains(query) ||
          row.driverEarnings.toStringAsFixed(0).contains(query) ||
          DateFormatter.short(row.date).toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return FeatureScaffold(
      title: copy.t('Revenue History', 'Historique des revenus'),
      children: [
        SearchFilterBar(
          hint: copy.t(
            'Search by Ride ID, amount, or date',
            'Rechercher par identifiant de course, montant ou date',
          ),
          onChanged: (value) => setState(() => _query = value),
          onFilter: () {},
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final range in _RevenueRange.values) ...[
                ChoiceChip(
                  label: Text(_rangeLabel(copy, range)),
                  selected: _range == range,
                  onSelected: (_) {
                    if (range == _RevenueRange.custom) {
                      _pickCustomRange();
                      return;
                    }
                    setState(() {
                      _range = range;
                      _future = _load();
                    });
                  },
                ),
                SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (_range == _RevenueRange.custom && _customDateRange != null) ...[
          SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickCustomRange,
            icon: Icon(Icons.date_range_rounded),
            label: Text(
              '${DateFormatter.short(_customDateRange!.start)} - ${DateFormatter.short(_customDateRange!.end)}',
            ),
          ),
        ],
        SizedBox(height: 16),
        FutureBuilder<List<RevenueTransaction>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _errorState(
                copy,
                () => setState(() => _future = _load()),
              );
            }
            final rows = _filter(snapshot.data ?? const []);
            if (rows.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    copy.t(
                      'No transactions found for this period.',
                      'Aucune transaction trouvée pour cette période.',
                    ),
                  ),
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
  }

  Widget _errorState(DriverCopy copy, VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Text(
          copy.t(
            'We could not load your revenue history. Please try again.',
            "Nous n'avons pas pu charger votre historique de revenus. "
                'Veuillez réessayer.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.danger),
        ),
        SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(copy.t('Retry', 'Réessayer')),
        ),
      ],
    ),
  );

  String _rangeLabel(DriverCopy copy, _RevenueRange range) => switch (range) {
    _RevenueRange.today => copy.t('Today', "Aujourd'hui"),
    _RevenueRange.week => copy.t('Week', 'Semaine'),
    _RevenueRange.month => copy.t('Month', 'Mois'),
    _RevenueRange.year => copy.t('Year', 'Année'),
    _RevenueRange.custom => copy.t('Custom', 'Personnalisé'),
  };
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.row});

  final RevenueTransaction row;

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return Padding(
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
                        ? copy.t('Trip earnings', 'Revenus de la course')
                        : copy.t(
                            'Trip #${row.rideId}',
                            'Course n° ${row.rideId}',
                          ),
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(
                  label: _statusLabel(copy, row.status),
                  tone: _statusTone(row.status),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              '${DateFormatter.short(row.date)} • ${DateFormatter.time(row.date)}',
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 12,
              ),
            ),
            Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: LabeledValue(
                    label: copy.t('Driver Earnings', 'Revenus du chauffeur'),
                    value: CurrencyFormatter.format(row.driverEarnings),
                    valueColor: AppColors.success,
                  ),
                ),
                Expanded(
                  child: LabeledValue(
                    label: copy.t('Trip Amount', 'Montant de la course'),
                    value: row.tripAmount == null
                        ? '—'
                        : CurrencyFormatter.format(row.tripAmount!),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LabeledValue(
                    label: copy.t('Payment Method', 'Mode de paiement'),
                    value: row.paymentMethod ?? '—',
                  ),
                ),
                Expanded(
                  child: LabeledValue(
                    label: copy.t('Fleet', 'Parc'),
                    value: row.fleetName ?? 'TheRain Direct',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DriverCopy copy, String? status) {
    final normalized = (status ?? 'completed').toLowerCase();
    if (normalized.contains('cancel')) return copy.t('Cancelled', 'Annulée');
    if (normalized == 'completed') return copy.t('Completed', 'Terminée');
    return normalized.isEmpty ? copy.t('Completed', 'Terminée') : normalized;
  }

  BadgeTone _statusTone(String? status) {
    final normalized = (status ?? 'completed').toLowerCase();
    if (normalized.contains('cancel')) return BadgeTone.danger;
    return BadgeTone.success;
  }
}
