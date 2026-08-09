import '../../services/api_client.dart';
import '../models/payment_request.dart';
import '../models/revenue_summary.dart';
import '../models/revenue_transaction.dart';

/// Real driver-revenue surface, backed by node-api (not this app's own
/// disconnected `driver_transactions` Firestore collection — see
/// driver_earning_repository.dart, which node-api's ride-completion/payout
/// logic never writes to). Every read here goes through node-api's
/// ownership-checked service functions so a driver can only ever see their
/// own earnings.
class DriverRevenueRepository {
  DriverRevenueRepository({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<RevenueSummary> getSummary(String driverId) async {
    final data = await _client.get(
      '/api/driver-payroll/$driverId/revenue/summary',
    );
    if (data is! Map<String, dynamic>) return RevenueSummary.empty;
    return RevenueSummary.fromJson(data);
  }

  Future<double> getWalletBalance(String driverId) async {
    final data = await _client.get('/api/driver-payroll/$driverId/wallet');
    if (data is! Map<String, dynamic>) return 0;
    return (data['balance'] as num?)?.toDouble() ?? 0;
  }

  /// Recent Transactions / Revenue History: joins the driver's real
  /// RIDE_EARNINGS wallet transactions with their matching ride record
  /// (fare/payment method/status) client-side. Best-effort — a transaction
  /// with no matching ride still shows (with just its earnings amount and
  /// date), it just won't have a trip fare/payment method to display.
  Future<List<RevenueTransaction>> getTransactions(
    String driverId, {
    String? fleetName,
    DateTime? from,
    DateTime? to,
    String? search,
    int limit = 500,
  }) async {
    String dateOnly(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final data = await _client.get(
      '/api/driver-payroll/$driverId/revenue/history',
      query: {
        'limit': limit.clamp(1, 500),
        if (from != null) 'from': dateOnly(from),
        if (to != null) 'to': dateOnly(to),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final earnings = (data as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    return earnings
        .map(
          (row) =>
              RevenueTransaction.fromEarningsRecord(row, fleetName: fleetName),
        )
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<PaymentRequest> submitPaymentRequest({
    required String driverId,
    required double amount,
    required PaymentRequestMethod method,
    required String accountDetails,
    String? notes,
  }) async {
    final data = await _client.post(
      '/api/driver-payroll/$driverId/payment-requests',
      body: {
        'amount': amount,
        'paymentMethod': method.apiValue,
        'accountDetails': accountDetails,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return PaymentRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PaymentRequest>> listPaymentRequests(String driverId) async {
    final data = await _client.get(
      '/api/driver-payroll/$driverId/payment-requests',
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (row) => PaymentRequest.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList(growable: false);
  }
}
