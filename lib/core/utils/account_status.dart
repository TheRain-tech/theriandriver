/// Mirrors node-api's utils/accountStatus.js#isAccountActive exactly - the server has written
/// `drivers/{uid}.accountStatus` in two different casings/values depending on which code path
/// approved the driver (driver.service.js#approve/reject/createManagedDriver write lowercase
/// "active"/"pending"/"rejected"; the older admin-approval flow that approved this platform's
/// real drivers wrote "approved"). node-api's own eligibility check already treats both as
/// equivalent; this client never did - every one of its accountStatus comparisons only accepted
/// the literal string "active", so a real, fully-approved driver whose accountStatus happened to
/// be "approved" was permanently shown "Awaiting approval"/blocked from going online, no matter
/// what else about their account was fixed. Reproduced live against a real production driver
/// account (accountStatus: "approved", verificationStatus: "approved", canReceiveRides: true).
const _activeAccountStatusAliases = {'active', 'approved'};
const _inactiveAccountStatusAliases = {
  'pending',
  'inactive',
  'rejected',
  'draft',
};

/// True if [accountStatus] is any alias this platform has ever written for "the driver's account
/// is approved and usable" - not just the literal string "active".
bool isAccountStatusActive(String? accountStatus) {
  final normalized = accountStatus?.trim().toLowerCase() ?? '';
  return _activeAccountStatusAliases.contains(normalized);
}

/// True if [accountStatus] is a recognized "not yet active" value (pending/inactive/rejected/
/// draft) - distinct from suspended/blocked, which is checked separately via
/// DriverProfile.isSuspended. An unrecognized value is neither active nor this - callers should
/// treat that case the same as "not active" without claiming it's specifically "pending".
bool isAccountStatusPending(String? accountStatus) {
  final normalized = accountStatus?.trim().toLowerCase() ?? '';
  return _inactiveAccountStatusAliases.contains(normalized);
}
