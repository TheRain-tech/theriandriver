import 'package:firebase_auth/firebase_auth.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../services/api_client.dart';
import '../mock/mock_driver_wallet.dart';
import '../models/app_enums.dart';
import '../models/driver_transaction.dart';
import '../models/driver_wallet.dart';

/// Real earnings/payout wallet, backed by node-api's driver-payroll REST API
/// (driverPayroll.service.js) - NOT the `driver_wallets` Firestore collection this repository
/// used to read directly. That collection is never written by any earning/crediting code path
/// (driverPayroll.service.js#creditDriverForRide credits `wallets/driver_{uid}` instead, via
/// walletService) - the old direct-Firestore read always returned an all-zero empty wallet,
/// which is why the Wallet screen looked like it "wasn't showing anything." Reproduced live on
/// a physical device.
class DriverWalletRepository {
  DriverWalletRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  // A minimum withdrawal floor isn't returned by the wallet summary endpoint (node-api enforces
  // its own minimum server-side, in driverPayroll.service.js#submitPaymentRequest) - kept here
  // only as a client-side fast-fail hint before making the network call, matching the value
  // already used as this model's default.
  static const double _minimumWithdrawalHint = 5000;

  String? get _uid => FirebaseConfig.isAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  Future<DriverWallet> getWallet() async {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return EnvConfig.previewMode ? mockDriverWallet : _emptyWallet('');
    }
    try {
      final response = await _apiClient.get('/api/driver-payroll/$uid/wallet');
      final data = _unwrap(response);
      return _walletFromSummary(data, uid);
    } on ApiException {
      rethrow;
    }
  }

  /// Not a live Firestore stream anymore (node-api's wallet summary is a REST endpoint, not a
  /// realtime one) - exposed as a single-value stream so the existing StreamBuilder-based
  /// screen keeps working without a full rewrite. Callers that want fresh data after an action
  /// (top-up, withdrawal) should call [getWallet] again rather than relying on this to push an
  /// update.
  Stream<DriverWallet> watchWallet() => Stream.fromFuture(getWallet());

  Future<List<DriverTransaction>> getTransactions() async {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return EnvConfig.previewMode || FirebaseConfig.useMockFallback
          ? List.unmodifiable(mockDriverTransactions)
          : const [];
    }
    final response = await _apiClient.get(
      '/api/driver-payroll/$uid/wallet/transactions',
      query: {'limit': 100},
    );
    final rows = _unwrapList(response);
    return rows.map((row) => _transactionFromRow(row, uid)).toList(
      growable: false,
    );
  }

  Stream<List<DriverTransaction>> watchTransactions() =>
      Stream.fromFuture(getTransactions());

  Future<void> requestWithdrawal(
    double amount, {
    required String paymentMethod,
    required String accountDetails,
    String? notes,
  }) async {
    final uid = _uid;
    if (uid == null) {
      if (EnvConfig.previewMode) return;
      throw StateError('Sign in before requesting a withdrawal.');
    }
    if (amount < _minimumWithdrawalHint) {
      throw StateError(
        'Amount must be at least XAF ${_minimumWithdrawalHint.round()}.',
      );
    }
    try {
      // The real, deployed endpoint - driverPayroll.routes.js's
      // POST /driver-payroll/:driverId/payment-requests (driverPayroll.service.js#
      // submitPaymentRequest). The previous implementation called a Cloud Function
      // ("createWithdrawalRequest") that does not exist anywhere in this project's Firebase
      // Functions source - every withdrawal attempt failed outright.
      await _apiClient.post(
        '/api/driver-payroll/$uid/payment-requests',
        body: {
          'amount': amount,
          'paymentMethod': paymentMethod,
          'accountDetails': accountDetails,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on ApiException catch (error) {
      throw StateError(error.message);
    }
  }

  Map<String, dynamic> _unwrap(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map) return data.cast<String, dynamic>();
      return response;
    }
    return const {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic response) {
    dynamic data = response;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      data = response['data'];
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const [];
  }

  DriverWallet _walletFromSummary(Map<String, dynamic> data, String uid) {
    final balance = (data['balance'] as num?)?.toDouble() ?? 0;
    final pendingPayoutAmount =
        (data['pendingPayoutAmount'] as num?)?.toDouble() ?? 0;
    return DriverWallet(
      id: data['walletId']?.toString() ?? 'driver_$uid',
      driverId: data['driverId']?.toString() ?? uid,
      balance: balance,
      // The wallet summary doesn't reserve pending-payout amounts out of `balance` server-side
      // (that only happens once a payment request is approved and actually paid), so what's
      // "available" right now is the full balance - pending payout requests are shown
      // separately via pendingBalance below, not subtracted twice.
      availableToWithdraw: balance,
      minimumWithdrawal: _minimumWithdrawalHint,
      payoutMethod: 'Mobile Money',
      payoutAccount: 'Set in Profile > Payout Details',
      updatedAt: DateTime.now(),
      pendingBalance: pendingPayoutAmount,
    );
  }

  DriverTransaction _transactionFromRow(
    Map<String, dynamic> row,
    String uid,
  ) {
    final type = row['type']?.toString().toUpperCase() ?? 'CREDIT';
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final signedAmount = type == 'DEBIT' ? -amount.abs() : amount.abs();
    return DriverTransaction(
      id: row['id']?.toString() ?? '',
      driverId: row['ownerId']?.toString() ?? uid,
      title: _titleFor(row['reason']?.toString() ?? type),
      type: type == 'DEBIT' ? 'withdrawal' : 'earning',
      amount: signedAmount,
      createdAt: _date(row['createdAt']),
      status: WithdrawalStatus.completed,
      reference: row['referenceId']?.toString(),
    );
  }

  String _titleFor(String reason) {
    final normalized = reason.replaceAll('_', ' ').trim().toLowerCase();
    if (normalized.isEmpty) return 'Wallet Transaction';
    return normalized
        .split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  DateTime _date(Object? value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    // Firestore Timestamp serialized through the REST API as {_seconds, _nanoseconds} or
    // {seconds, nanoseconds} depending on the SDK version that touched it last.
    if (value is Map) {
      final seconds =
          value['_seconds'] ?? value['seconds'] ?? value['secondsSinceEpoch'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
        );
      }
    }
    return DateTime.now();
  }

  DriverWallet _emptyWallet(String uid) => DriverWallet(
    id: uid.isEmpty ? '' : 'driver_$uid',
    driverId: uid,
    balance: 0,
    availableToWithdraw: 0,
    minimumWithdrawal: _minimumWithdrawalHint,
    payoutMethod: 'Mobile Money',
    payoutAccount: 'No payout number configured',
    updatedAt: DateTime.now(),
  );
}
