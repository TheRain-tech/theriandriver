import '../../data/models/driver_profile.dart';
import '../../data/models/fleet_info.dart';

bool isConfirmedFleetDriver(DriverProfile profile, FleetInfo? fleet) {
  final fleetId = profile.currentFleetId?.trim();
  if (fleetId == null || fleetId.isEmpty || fleet?.id != fleetId) return false;

  final fleetStatus = fleet!.status.trim().toLowerCase();
  final approvalStatus = fleet.approvalStatus?.trim().toLowerCase();
  return fleetStatus == 'approved' &&
      (approvalStatus == null ||
          approvalStatus.isEmpty ||
          approvalStatus == 'approved');
}
