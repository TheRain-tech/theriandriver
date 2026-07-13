import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/firebase_config.dart';
import '../data/models/commission_wallet.dart';
import '../data/models/driver_profile.dart';
import '../firebase/firestore_collections.dart';

class CommissionWalletService {
  CommissionWalletService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestoreOverride = firestore,
       _functionsOverride = functions;

  static final instance = CommissionWalletService();

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  Future<CommissionWallet> getWalletForDriver(DriverProfile profile) async {
    final walletRef = _db
        .collection(FirestoreCollections.commissionWallets)
        .doc(_walletIdFor(profile));
    if (!FirebaseConfig.isAvailable) {
      return CommissionWallet.empty(
        walletId: walletRef.id,
        ownerType: _ownerTypeFor(profile),
        ownerId: _ownerIdFor(profile),
      );
    }
    final snapshot = await walletRef.get();
    final data = snapshot.data();
    if (data == null) {
      return CommissionWallet.empty(
        walletId: walletRef.id,
        ownerType: _ownerTypeFor(profile),
        ownerId: _ownerIdFor(profile),
      );
    }
    return CommissionWallet.fromMap(data, snapshot.id);
  }

  Stream<CommissionWallet> watchWalletForDriver(DriverProfile profile) {
    final walletId = _walletIdFor(profile);
    if (!FirebaseConfig.isAvailable) {
      return Stream.value(
        CommissionWallet.empty(
          walletId: walletId,
          ownerType: _ownerTypeFor(profile),
          ownerId: _ownerIdFor(profile),
        ),
      );
    }
    return _db
        .collection(FirestoreCollections.commissionWallets)
        .doc(walletId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null
              ? CommissionWallet.empty(
                  walletId: walletId,
                  ownerType: _ownerTypeFor(profile),
                  ownerId: _ownerIdFor(profile),
                )
              : CommissionWallet.fromMap(data, snapshot.id);
        });
  }

  Future<CommissionWalletEligibility> evaluateGoOnline(
    DriverProfile profile,
  ) async {
    final wallet = await getWalletForDriver(profile);
    if (wallet.status == 'blocked') {
      return CommissionWalletEligibility.blocked(
        'Commission wallet is blocked. Contact support.',
        wallet: wallet,
      );
    }
    if (!wallet.canReceiveRides) {
      return CommissionWalletEligibility.blocked(
        'Top up your commission balance to receive rides.',
        wallet: wallet,
      );
    }
    return CommissionWalletEligibility.allowedWith(wallet);
  }

  Future<void> requestServerSideCommissionDeduction({
    required String rideId,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    await _functions.httpsCallable('deductRideCommission').call({
      'rideId': rideId,
    });
  }

  String _walletIdFor(DriverProfile profile) {
    final explicit = profile.commissionWalletId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final ownerType = _ownerTypeFor(profile);
    final ownerId = _ownerIdFor(profile);
    return '$ownerType-$ownerId';
  }

  String _ownerTypeFor(DriverProfile profile) {
    if (profile.commissionWalletOwnerType.isNotEmpty) {
      return profile.commissionWalletOwnerType;
    }
    if (profile.driverType == 'fleet' && profile.fleetId != null) {
      return 'fleet';
    }
    return 'driver';
  }

  String _ownerIdFor(DriverProfile profile) {
    if (_ownerTypeFor(profile) == 'fleet' && profile.fleetId != null) {
      return profile.fleetId!;
    }
    return profile.id;
  }
}
