import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return FeatureScaffold(
    title: l.t('Payment History', 'Historique des paiements'),
    children: [
      SearchFilterBar(
        hint: l.t('Search by amount, reference, or date', 'Rechercher par montant, référence ou date'),
        onChanged: (value) => setState(() => _query = value),
        onFilter: () {},
      ),
      SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _HistoryFilter.values) ...[
              ChoiceChip(
                label: Text(_label(filter, l)),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
              SizedBox(width: 8),
            ],
          ],
        ),
      ),
      SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: null,
          icon: Icon(Icons.ios_share_rounded, size: 18),
          label: Text(l.t('Export (coming soon)', 'Export (bientôt disponible)')),
        ),
      ),
      SizedBox(height: 8),
      FutureBuilder<List<PaymentRequest>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Text(
                    l.t(
                      'We could not load your payment history.',
                      "Impossible de charger votre historique de paiements.",
                    ),
                    style: TextStyle(color: AppColors.danger),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: Text(l.t('Retry', 'Réessayer')),
                  ),
                ],
              ),
            );
          }
          final rows = _apply(snapshot.data ?? const []);
          if (rows.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(l.t('No payment requests yet.', 'Aucune demande de paiement pour le moment.')),
              ),
            );
          }
          return Column(
            children: [for (final row in rows) _HistoryCard(row: row)],
          );
        },
      ),
    ],
  );
  }

  String _label(_HistoryFilter filter, DriverCopy l) => switch (filter) {
    _HistoryFilter.all => l.t('All', 'Toutes'),
    _HistoryFilter.pending => l.t('Pending', 'En attente'),
    _HistoryFilter.approved => l.t('Approved', 'Approuvée'),
    _HistoryFilter.paid => l.t('Paid', 'Payée'),
    _HistoryFilter.rejected => l.t('Rejected', 'Rejetée'),
  };
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row});

  final PaymentRequest row;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
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
                  CurrencyFormatter.format(row.amount),
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              StatusBadge(
                label: _statusLabel(row.status, l),
                tone: _tone(row.status),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            DateFormatter.full(row.requestedAt),
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
                  label: l.t('Payment Method', 'Méthode de paiement'),
                  value: row.paymentMethod == PaymentRequestMethod.bankTransfer
                      ? l.t('Bank Transfer', 'Virement bancaire')
                      : row.paymentMethod.label,
                ),
              ),
              Expanded(
                child: LabeledValue(
                  label: l.t('Transaction Ref', 'Référence de transaction'),
                  value: row.transactionReference ?? '—',
                ),
              ),
            ],
          ),
          if (row.status == 'PAID' && row.remainingBalance != null) ...[
            SizedBox(height: 12),
            LabeledValue(
              label: l.t('Remaining Balance', 'Solde restant'),
              value: CurrencyFormatter.format(row.remainingBalance!),
            ),
          ],
          if (row.status == 'REJECTED' && row.rejectionReason != null) ...[
            SizedBox(height: 12),
            Text(
              l.t(
                'Reason: ${row.rejectionReason}',
                'Motif : ${row.rejectionReason}',
              ),
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
  }

  String _statusLabel(String status, DriverCopy l) => switch (status) {
    'PENDING' => l.t('Pending', 'En attente'),
    'APPROVED' => l.t('Approved', 'Approuvée'),
    'PAID' => l.t('Paid', 'Payée'),
    'REJECTED' => l.t('Rejected', 'Rejetée'),
    _ => status,
  };

  BadgeTone _tone(String status) => switch (status) {
    'PAID' => BadgeTone.success,
    'APPROVED' => BadgeTone.info,
    'REJECTED' => BadgeTone.danger,
    _ => BadgeTone.warning,
  };
}
