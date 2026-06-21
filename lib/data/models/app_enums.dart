enum DriverVerificationStatus {
  notStarted,
  inProgress,
  pending,
  approved,
  rejected,
  resubmissionRequired,
}

enum DriverOnlineStatus { offline, online, busy }

enum TripStatus {
  requested,
  accepted,
  goingToPickup,
  arrived,
  inProgress,
  completed,
  cancelled,
  missed,
}

enum PaymentMethod { cash, mobileMoney }

enum PaymentStatus { pending, paid, failed, refunded }

enum DocumentStatus { notUploaded, uploaded, pending, verified, rejected }

enum WithdrawalStatus { pending, completed, failed }

enum SupportTicketStatus { open, inProgress, resolved, closed }

T enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  return values.where((item) => item.name == value).firstOrNull ?? fallback;
}
