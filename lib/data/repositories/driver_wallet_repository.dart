import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../mock/mock_driver_wallet.dart';
import '../models/app_enums.dart';
import '../models/driver_transaction.dart';
import '../models/driver_wallet.dart';

class DriverWalletRepository {
  DriverWalletRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestoreOverride = firestore,
       _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;
  String? get _uid => FirebaseConfig.isAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  Stream<DriverWallet> watchWallet() {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return Stream.value(mockDriverWallet);
    }
    return _db
        .collection(FirestoreCollections.driverWallets)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null
              ? _emptyWallet(uid)
              : DriverWallet.fromMap(data, snapshot.id);
        });
  }

  Future<DriverWallet> getWallet() => watchWallet().first;

  Stream<List<DriverTransaction>> watchTransactions() {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return Stream.value(
        EnvConfig.previewMode || FirebaseConfig.useMockFallback
            ? List.unmodifiable(mockDriverTransactions)
            : const [],
      );
    }
    return _db
        .collection(FirestoreCollections.driverTransactions)
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = document.data();
                return DriverTransaction(
                  id: data['transactionId']?.toString() ?? document.id,
                  driverId: data['driverId']?.toString() ?? uid,
                  title: data['title']?.toString() ?? 'Transaction',
                  type: data['type']?.toString() ?? '',
                  amount: (data['amount'] as num?)?.toDouble() ?? 0,
                  createdAt: _date(data['createdAt']),
                  status: enumByName(
                    WithdrawalStatus.values,
                    data['status'],
                    WithdrawalStatus.pending,
                  ),
                  reference:
                      data['rideId']?.toString() ??
                      data['reference']?.toString(),
                );
              })
              .toList(growable: false),
        );
  }

  Future<List<DriverTransaction>> getTransactions() =>
      watchTransactions().first;

  Future<void> requestWithdrawal(double amount) async {
    final uid = _uid;
    if (uid == null) {
      if (EnvConfig.previewMode) return;
      throw StateError('Sign in before requesting a withdrawal.');
    }
    final wallet = await getWallet();
    if (amount < wallet.minimumWithdrawal) {
      throw StateError(
        'Amount must be at least XAF ${wallet.minimumWithdrawal.round()}.',
      );
    }
    if (amount > wallet.availableToWithdraw) {
      throw StateError('Insufficient funds available for withdrawal.');
    }

    try {
      await _functions.httpsCallable('createWithdrawalRequest').call({
        'amount': amount,
        'currency': 'XAF',
      });
      return;
    } on FirebaseFunctionsException {
      if (!kDebugMode) rethrow;
    }

    // Development fallback only creates the pending request. Wallet balances
    // remain server-owned and are not decremented by the Flutter client.
    final transactionRef = _db
        .collection(FirestoreCollections.driverTransactions)
        .doc();
    await transactionRef.set({
      'transactionId': transactionRef.id,
      'driverId': uid,
      'rideId': null,
      'type': 'withdrawal',
      'amount': amount,
      'currency': 'XAF',
      'status': 'pending',
      'title': 'Withdrawal Request',
      'description': 'Mobile Money payout pending administrator approval',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  DriverWallet _emptyWallet(String uid) => DriverWallet(
    id: uid,
    driverId: uid,
    balance: 0,
    availableToWithdraw: 0,
    minimumWithdrawal: 5000,
    payoutMethod: 'Mobile Money',
    payoutAccount: 'No payout number configured',
    updatedAt: DateTime.now(),
  );

  DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
