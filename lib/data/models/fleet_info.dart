/// Public fleet info a fleet-linked driver sees on their own Profile screen
/// (Fleet Information section) and Fleet Agreement screen. Sourced directly
/// from the `fleets/{fleetId}` Firestore document node-api's fleet.service.js
/// already maintains — no new backend surface needed for this read.
class FleetInfo {
  const FleetInfo({
    required this.id,
    required this.fleetName,
    required this.companyName,
    this.logoUrl,
    required this.status,
    this.approvalStatus,
    this.email,
    this.phoneNumber,
    this.address,
  });

  final String id;
  final String fleetName;
  final String companyName;
  final String? logoUrl;
  final String status;
  final String? approvalStatus;
  final String? email;
  final String? phoneNumber;
  final String? address;

  /// Verified / Pending / Suspended — the three states the Driver Profile
  /// spec calls out. Falls back to reading fleet.status/approvalStatus in
  /// whichever shape fleet.service.js actually populated (lowercase
  /// "approved"/"pending"/"rejected" from applyForFleetAccount, or the
  /// generic ACTIVE/INACTIVE/SUSPENDED account status).
  String get displayStatus {
    final normalized = (approvalStatus ?? status).toUpperCase();
    if (normalized.contains('SUSPEND')) return 'Suspended';
    if (normalized.contains('PENDING')) return 'Pending';
    if (normalized.contains('REJECT')) return 'Rejected';
    if (normalized.contains('APPROVED') || normalized.contains('ACTIVE')) {
      return 'Verified';
    }
    return normalized.isEmpty ? 'Pending' : normalized;
  }

  factory FleetInfo.fromMap(Map<String, dynamic> map, String id) {
    return FleetInfo(
      id: id,
      fleetName:
          map['fleetName']?.toString() ??
          map['companyName']?.toString() ??
          map['name']?.toString() ??
          'Fleet Partner',
      companyName:
          map['companyName']?.toString() ??
          map['fleetName']?.toString() ??
          map['businessName']?.toString() ??
          '',
      logoUrl:
          map['fleetLogo']?.toString() ??
          map['logoUrl']?.toString() ??
          map['logo']?.toString(),
      status: map['status']?.toString() ?? map['accountStatus']?.toString() ?? '',
      approvalStatus:
          map['approvalStatus']?.toString() ?? map['reviewStatus']?.toString(),
      email: map['email']?.toString() ?? map['contactEmail']?.toString(),
      phoneNumber:
          map['phoneNumber']?.toString() ?? map['phone']?.toString(),
      address:
          map['address']?.toString() ??
          (map['metadata'] is Map
              ? (map['metadata'] as Map)['address']?.toString()
              : null),
    );
  }
}
