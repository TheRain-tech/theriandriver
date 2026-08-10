import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/commission_wallet.dart';
import '../data/models/driver_profile.dart';
import '../firebase/firestore_collections.dart';
import 'api_client.dart';

/// Prepaid commission wallet for independent (non-fleet) drivers - a driver's own top-up float
/// that gates receiving rides. Backed by node-api's real REST endpoint
/// (driverPayroll.routes.js `GET/POST /:driverId/commission-wallet[...]`), not a direct Firestore
/// read of `commission_wallets/{ownerType}-{ownerId}` like this service used to do: that
/// collection has no rule in the deployed firestore.rules at all (only a stale copy in this
/// app's own checked-in `firestore.rules` reference file ever had one), so every read was
/// silently permission-denied - the "Commission Balance" card always showed 0 with no error
/// surfaced, and evaluateGoOnline() below would have thrown an unhandled permission-denied
/// exception the moment a driver's dashboard gate ever cleared.
///
/// Fleet-affiliated drivers are a separate case: they draw down their *fleet's* wallet
/// (wallets/fleet_{fleetId}, topped up by the fleet admin - see payment.service.js
/// #initiateFleetWalletDeposit), which node-api already enforces server-side on every
/// go-online attempt (driver.service.js#toggleOnline -> fleetWallet.service.js
/// #assertFleetCanAcceptRides). This service intentionally does not read or gate on that -
/// it has no per-driver balance to show, and the server is already the authoritative check.
class CommissionWalletService {
  CommissionWalletService({ApiClient? apiClient, FirebaseFirestore? firestore})
    : _apiClient = apiClient ?? ApiClient.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  static final instance = CommissionWalletService();

  final ApiClient _apiClient;
  final FirebaseFirestore _db;

  bool _isFleetDriver(DriverProfile profile) =>
      profile.driverType == 'fleet' &&
      (profile.fleetId ?? '').trim().isNotEmpty;

  CommissionWallet _fleetPlaceholder(DriverProfile profile) => CommissionWallet(
    walletId: 'fleet_${profile.fleetId}',
    ownerType: 'fleet',
    ownerId: profile.fleetId ?? '',
    balance: 0,
    currency: 'XAF',
    minimumRequiredBalance: 0,
    lowBalanceThreshold: 0,
    // Always reported active: the fleet's own wallet balance (not shown here) is what actually
    // gates going online, enforced server-side. See class doc comment above.
    status: 'active',
    updatedAt: DateTime.now(),
  );

  Future<CommissionWallet> getWalletForDriver(DriverProfile profile) async {
    if (_isFleetDriver(profile)) return _fleetPlaceholder(profile);
    try {
      final response = await _apiClient.get(
        '/api/driver-payroll/${profile.id}/commission-wallet',
      );
      final data = response is Map<String, dynamic>
          ? (response['data'] is Map
                ? Map<String, dynamic>.from(response['data'] as Map)
                : response)
          : <String, dynamic>{};
      return CommissionWallet.fromSummary(data);
    } on ApiException {
      // Commission balances are server-managed, but their canonical wallet
      // documents are owner-readable. Fall back to that read-only view when
      // the API is temporarily unreachable so funded drivers are not blocked
      // by a false "low balance" state.
      try {
        final snapshot = await _db
            .collection(FirestoreCollections.fleetWallets)
            .doc('driver_commission_${profile.id}')
            .get();
        if (snapshot.exists) {
          return CommissionWallet.fromSummary({
            ...?snapshot.data(),
            'walletId': snapshot.id,
            'driverId': profile.id,
          });
        }
      } on FirebaseException {
        // Continue to the empty state below. It keeps the Top Up action
        // available if neither source can currently be reached.
      }
      return CommissionWallet.empty(
        walletId: 'driver_commission_${profile.id}',
        ownerType: 'driver',
        ownerId: profile.id,
      );
    }
  }

  Stream<CommissionWallet> watchWalletForDriver(DriverProfile profile) =>
      Stream.fromFuture(getWalletForDriver(profile));

  Future<CommissionWalletEligibility> evaluateGoOnline(
    DriverProfile profile,
  ) async {
    if (_isFleetDriver(profile)) {
      // Fleet wallet sufficiency is enforced server-side on the actual go-online call
      // (assertFleetCanAcceptRides) - no client-side pre-check to duplicate here.
      return const CommissionWalletEligibility(
        allowed: true,
        reason: 'Fleet wallet covers ride commission.',
      );
    }
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
}
