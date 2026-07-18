import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/payment_request.dart';
import '../../../data/repositories/driver_revenue_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/search_filter_bar.dart';

enum _HistoryFilter { all, pending, approved, paid, rejected }

/// TheRain-direct drivers ONLY: Payment Date, Amount, Payment Method,
/// Transaction Reference, Status, Remaining Balance — with Search/Filter/
/// Export(stub).
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _repository = DriverRevenueRepository();
  late Future<List<PaymentRequest>> _future;
  _HistoryFilter _filter = _HistoryFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PaymentRequest>> _load() {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return Future.value(const []);
    return _repository.listPaymentRequests(uid);
  }

  List<PaymentRequest> _apply(List<PaymentRequest> rows) {
    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      if (_filter != _HistoryFilter.all &&
          row.status.toLowerCase() != _filter.name) {
        return false;
      }
      if (query.isEmpty) return true;
      return row.amount.toStringAsFixed(0).contains(query) ||
          (row.transactionReference ?? '').toLowerCase().contains(query) ||
          DateFormatter.short(row.requestedAt).toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Payment History',
    children: [
      SearchFilterBar(
        hint: 'Search by amount, reference, or date',
        onChanged: (value) => setState(() => _query = value),
        onFilter: () {},
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _HistoryFilter.values) ...[
              ChoiceChip(
                label: Text(_label(filter)),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: null,
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Export (coming soon)'),
        ),
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<PaymentRequest>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Text(
                    'We could not load your payment history.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final rows = _apply(snapshot.data ?? const []);
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No payment requests yet.')),
            );
          }
          return Column(
            children: [for (final row in rows) _HistoryCard(row: row)],
          );
        },
      ),
    ],
  );

  String _label(_HistoryFilter filter) => switch (filter) {
    _HistoryFilter.all => 'All',
    _HistoryFilter.pending => 'Pending',
    _HistoryFilter.approved => 'Approved',
    _HistoryFilter.paid => 'Paid',
    _HistoryFilter.rejected => 'Rejected',
  };
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row});

  final PaymentRequest row;

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
                  CurrencyFormatter.format(row.amount),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              StatusBadge(
                label: _statusLabel(row.status),
                tone: _tone(row.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormatter.full(row.requestedAt),
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: 'Payment Method',
                  value: row.paymentMethod.label,
                ),
              ),
              Expanded(
                child: LabeledValue(
                  label: 'Transaction Ref',
                  value: row.transactionReference ?? '—',
                ),
              ),
            ],
          ),
          if (row.status == 'PAID' && row.remainingBalance != null) ...[
            const SizedBox(height: 12),
            LabeledValue(
              label: 'Remaining Balance',
              value: CurrencyFormatter.format(row.remainingBalance!),
            ),
          ],
          if (row.status == 'REJECTED' && row.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Text(
              'Reason: ${row.rejectionReason}',
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );

  String _statusLabel(String status) => switch (status) {
    'PENDING' => 'Pending',
    'APPROVED' => 'Approved',
    'PAID' => 'Paid',
    'REJECTED' => 'Rejected',
    _ => status,
  };

  BadgeTone _tone(String status) => switch (status) {
    'PAID' => BadgeTone.success,
    'APPROVED' => BadgeTone.info,
    'REJECTED' => BadgeTone.danger,
    _ => BadgeTone.warning,
  };
}
