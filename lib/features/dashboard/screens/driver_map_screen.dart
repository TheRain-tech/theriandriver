import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/map_preview_card.dart';
import '../widgets/road_alert_button.dart';
import '../../../services/driver_profile_service.dart';

/// Bottom-nav Map tab: the driver's own live location, independent of any
/// active ride (an active ride's own tracking map is a separate screen).
/// Reuses the exact same MapPreviewCard + LocationService.instance.currentLocation
/// feed the dashboard's embedded map already uses - no new location plumbing.
class DriverMapScreen extends StatelessWidget {
  const DriverMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final profile = DriverProfileService.instance.profile.value;
    return Scaffold(
      appBar: DriverAppBar(title: copy.map, showLogo: false),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPreviewCard(
              expand: true,
              borderRadius: BorderRadius.zero,
              driverRideType: profile.vehicleType,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(bottom: false, child: RoadAlertButton()),
          ),
        ],
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 1),
    );
  }
}
