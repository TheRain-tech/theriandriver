import '../../core/localization/driver_copy.dart';
import '../../core/utils/currency_formatter.dart';
import 'driver_profile.dart';

/// Whose wallet must hold money before this driver goes online / accepts a ride. The server decides
/// (node-api services/driverWalletRequirement.service.js, plus the Cloud Functions and Firestore
/// rules); this only mirrors that decision so the app can show the right screen and wording, and is
/// never what allows or blocks a ride.
enum DriverWalletCategory {
  /// The fleet owner's wallet must hold the minimum; the driver has no wallet requirement.
  fleet,

  /// Goes online with an empty balance. Approval and safety restrictions still apply.
  therainManaged,

  /// Own vehicle: the driver's own TheRain wallet must hold the minimum.
  ownVehicle,
}

DriverWalletCategory walletCategoryOf(DriverProfile profile) {
  if (profile.isFleetDriver) return DriverWalletCategory.fleet;
  final raw = (profile.affiliationType ?? profile.driverType)
      .trim()
      .toLowerCase();
  if (raw == 'fleet') return DriverWalletCategory.fleet;
  if (raw == 'therain_managed' || raw == 'company' || raw == 'enterprise') {
    return DriverWalletCategory.therainManaged;
  }
  return DriverWalletCategory.ownVehicle;
}

/// The server's answer to "can this driver go online / accept rides, wallet-wise?"
/// (`GET /api/drivers/me/wallet-requirement`).
class DriverWalletRequirement {
  const DriverWalletRequirement({
    required this.category,
    required this.needsWallet,
    required this.minimumBalance,
    required this.canGoOnline,
    this.balance,
    this.code,
  });

  final String category;
  final bool needsWallet;
  final double minimumBalance;
  final bool canGoOnline;

  /// Only reported for an own-vehicle driver (a fleet's balance is not the driver's to see).
  final double? balance;

  /// Stable server code of the block, e.g. DRIVER_WALLET_INSUFFICIENT.
  final String? code;

  factory DriverWalletRequirement.fromJson(Map<String, dynamic> json) =>
      DriverWalletRequirement(
        category: json['category']?.toString() ?? '',
        needsWallet: json['required'] == true,
        minimumBalance: (json['minimumBalance'] as num?)?.toDouble() ?? 0,
        canGoOnline: json['canGoOnline'] != false,
        balance: (json['balance'] as num?)?.toDouble(),
        code: json['code']?.toString(),
      );

  /// What to tell the driver, in their language; null when nothing blocks them.
  String? blockMessage([DriverCopy? copy]) => walletBlockMessage(
    code,
    minimumBalance: minimumBalance,
    balance: balance,
    copy: copy,
  );
}

const walletBlockCodes = {
  'DRIVER_WALLET_INSUFFICIENT',
  'DRIVER_WALLET_BLOCKED',
  'FLEET_WALLET_INSUFFICIENT',
  'FLEET_NOT_ACTIVE',
  'FLEET_MEMBERSHIP_MISSING',
};

/// The driver-facing explanation for a wallet block code (English or French). Returns null for a code
/// that is not a wallet block, so callers fall back to the server's own message. Without the server's
/// minimum (e.g. the block came back on the go-online call itself) the wording stays accurate without
/// quoting an amount.
String? walletBlockMessage(
  String? code, {
  double minimumBalance = 0,
  double? balance,
  DriverCopy? copy,
}) {
  final c = copy ?? DriverCopy.current;
  final known = minimumBalance > 0;
  final minimum = CurrencyFormatter.format(minimumBalance);
  switch (code) {
    case 'DRIVER_WALLET_INSUFFICIENT':
      final current = balance == null
          ? ''
          : ' (${CurrencyFormatter.format(balance)})';
      final shortfall = balance != null && known
          ? CurrencyFormatter.format(
              (minimumBalance - balance).clamp(0, double.infinity),
            )
          : null;
      return c.t(
        'Your TheRain wallet balance$current is below ${known ? 'the $minimum' : 'the required minimum'} needed to go online and accept rides.${shortfall == null ? '' : ' Top up at least $shortfall to continue.'}',
        'Le solde de votre portefeuille TheRain$current est inférieur ${known ? 'aux $minimum' : 'au minimum requis'} nécessaire pour se mettre en ligne et accepter des courses.${shortfall == null ? '' : ' Rechargez au moins $shortfall pour continuer.'}',
      );
    case 'DRIVER_WALLET_BLOCKED':
      return c.t(
        'Your TheRain wallet is blocked. Please contact support.',
        "Votre portefeuille TheRain est bloqué. Veuillez contacter l'assistance.",
      );
    case 'FLEET_WALLET_INSUFFICIENT':
      return c.t(
        "Your Fleet Owner's wallet is below ${known ? 'the $minimum' : 'the minimum'} required. Ask your Fleet Owner to recharge the Fleet Wallet - you can go online and accept rides as soon as it is topped up.",
        "Le portefeuille de votre propriétaire de flotte est inférieur ${known ? 'aux $minimum' : 'au minimum'} requis. Demandez-lui de recharger le portefeuille de la flotte - vous pourrez vous mettre en ligne et accepter des courses dès qu'il sera rechargé.",
      );
    case 'FLEET_NOT_ACTIVE':
      return c.t(
        'Your fleet is not currently active, so ride requests are unavailable. Contact your Fleet Owner.',
        "Votre flotte n'est pas active pour le moment, les demandes de course sont donc indisponibles. Contactez votre propriétaire de flotte.",
      );
    case 'FLEET_MEMBERSHIP_MISSING':
      return c.t(
        'You are not attached to a fleet yet. Join a fleet or contact your Fleet Owner.',
        "Vous n'êtes pas encore rattaché à une flotte. Rejoignez une flotte ou contactez votre propriétaire de flotte.",
      );
  }
  return null;
}
