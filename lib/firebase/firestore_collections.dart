abstract final class FirestoreCollections {
  static const users = 'users';
  static const drivers = 'drivers';
  static const driverVerifications = 'driver_verifications';
  static const driverVehicles = 'driver_vehicles';
  static const driverDocuments = 'driver_documents';
  static const driverLiveLocations = 'driver_live_locations';
  static const riderLiveLocations = 'rider_live_locations';
  static const rideRequests = 'ride_requests';
  static const rides = 'rides';
  static const pricingRules = 'pricing_rules';
  static const driverWallets = 'driver_wallets';
  static const driverTransactions = 'driver_transactions';
  static const notifications = 'notifications';
  static const driverSupportTickets = 'driver_support_tickets';
  static const driverActivityLogs = 'driver_activity_logs';
  static const sosAlerts = 'sos_alerts';
}

abstract final class RideStatuses {
  // Exact values used by the Rider App contract.
  static const requested = 'requested';
  static const searching = 'searching_driver';
  static const accepted = 'driver_assigned';
  static const driverArriving = 'driver_arriving';
  static const arrived = 'driver_arrived';
  static const ongoing = 'in_progress';
  static const completed = 'completed';
  static const cancelled =
      'cancelled_by_driver'; // default write status for driver cancellation
  static const cancelledByRider = 'cancelled_by_rider';
  static const cancelledByDriver = 'cancelled_by_driver';
  static const expired = 'request_timeout';

  static const all = {
    requested,
    searching,
    accepted,
    driverArriving,
    arrived,
    ongoing,
    completed,
    cancelled,
    cancelledByRider,
    expired,
  };
}

abstract final class PaymentStatuses {
  static const pending = 'pending';
  static const paid = 'paid';
  static const failed = 'failed';
}
