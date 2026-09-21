import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/commission_wallet.dart';
import '../data/models/driver_profile.dart';
import '../data/models/driver_wallet_requirement.dart';
import '../core/localization/driver_copy.dart';
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
      _firestoreOverride = firestore;

  static final instance = CommissionWalletService();

  final ApiClient _apiClient;
  final FirebaseFirestore? _firestoreOverride;

  // Lazy, not a field set at construction: `static final instance =
  // CommissionWalletService()` evaluates on first access to `.instance`, so an eager
  // `FirebaseFirestore.instance` there throws [core/no-app] the moment anything touches this
  // service before Firebase.initializeApp() has run (every widget test, and preview mode) -
  // before getWalletForDriver's own FirebaseException fallback handling ever gets a chance to
  // run. Deferring to first real use means only a caller that actually needs the Firestore
  // fallback pays for it, and only once Firebase is guaranteed to exist.
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

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

  /// The server's wallet verdict for this driver: fleet driver -> the fleet's wallet, own-vehicle
  /// driver -> their own wallet, TheRain-managed -> none needed. Null when the server cannot be reached
  /// (the server enforces the same rule on the real go-online / accept call, so an unreachable check
  /// never wrongly locks a driver out here).
  Future<DriverWalletRequirement?> fetchRequirement() async {
    try {
      final response = await _apiClient.get(
        '/api/drivers/me/wallet-requirement',
      );
      final data = response is Map<String, dynamic>
          ? (response['data'] is Map
                ? Map<String, dynamic>.from(response['data'] as Map)
                : response)
          : <String, dynamic>{};
      if (data.isEmpty) return null;
      return DriverWalletRequirement.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  Future<CommissionWalletEligibility> evaluateGoOnline(
    DriverProfile profile,
  ) async {
    final category = walletCategoryOf(profile);
    if (category == DriverWalletCategory.therainManaged) {
      // A TheRain-managed driver goes online with an empty balance: no wallet requirement of any kind.
      // (Approval and safety restrictions are checked elsewhere and still apply.)
      return CommissionWalletEligibility(
        allowed: true,
        reason: DriverCopy.current.t(
          'No wallet balance is required for TheRain-managed drivers.',
          'Aucun solde de portefeuille n\'est requis pour les chauffeurs gérés par TheRain.',
        ),
      );
    }
    final requirement = await fetchRequirement();
    if (requirement != null && !requirement.canGoOnline) {
      return CommissionWalletEligibility.blocked(
        requirement.blockMessage() ??
            DriverCopy.current.t(
              'You cannot go online right now. Please try again.',
              'Vous ne pouvez pas vous mettre en ligne pour le moment. Veuillez réessayer.',
            ),
        wallet: category == DriverWalletCategory.ownVehicle
            ? await getWalletForDriver(profile)
            : null,
      );
    }
    if (category == DriverWalletCategory.fleet) {
      return CommissionWalletEligibility(
        allowed: true,
        reason: DriverCopy.current.t(
          'Your fleet wallet covers ride commission.',
          'Le portefeuille de votre flotte couvre la commission des courses.',
        ),
      );
    }
    return CommissionWalletEligibility.allowedWith(
      await getWalletForDriver(profile),
    );
  }
}
