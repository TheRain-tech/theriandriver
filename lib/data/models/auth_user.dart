class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.displayName,
    this.isMock = false,
    this.viaDefaultPool = false,
  });

  final String uid;
  final String email;
  final String phoneNumber;
  final String displayName;
  final bool isMock;

  /// True when this login was found in the shared default pool (where riders - and drivers who
  /// registered before driver logins had their own pool - live) instead of the driver pool. Such a
  /// login is only a driver account if a driver profile exists for it; see
  /// AuthService._assertDriverAccount.
  final bool viaDefaultPool;
}
