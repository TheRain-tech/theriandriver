import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/fleet_info.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../driver_navigation_mode.dart';

class DriverBottomNav extends StatelessWidget {
  const DriverBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<DriverProfile>(
      valueListenable: DriverProfileService.instance.profile,
      builder: (context, profile, _) => ValueListenableBuilder<bool>(
        valueListenable: DriverProfileService.instance.profileResolved,
        builder: (context, profileReady, _) =>
            ValueListenableBuilder<FleetInfo?>(
              valueListenable: DriverProfileService.instance.fleetInfo,
              builder: (context, fleet, _) => ValueListenableBuilder<bool>(
                valueListenable:
                    DriverProfileService.instance.fleetInfoResolved,
                builder: (context, fleetReady, _) {
                  if (!profileReady ||
                      (profile.currentFleetId != null && !fleetReady)) {
                    return const SizedBox(height: 80);
                  }
                  final isFleetDriver = isConfirmedFleetDriver(profile, fleet);
                  final destinations =
                      <({String route, IconData icon, String label})>[
                        (
                          route: RouteNames.dashboard,
                          icon: Icons.home_outlined,
                          label: copy.home,
                        ),
                        (
                          route: RouteNames.trips,
                          icon: Icons.directions_car_outlined,
                          label: copy.trip,
                        ),
                        if (isFleetDriver)
                          (
                            route: RouteNames.chatTab,
                            icon: Icons.chat_bubble_outline_rounded,
                            label: copy.chat,
                          )
                        else
                          (
                            route: RouteNames.wallet,
                            icon: Icons.account_balance_wallet_outlined,
                            label: copy.wallet,
                          ),
                        (
                          route: RouteNames.earnings,
                          icon: Icons.monetization_on_outlined,
                          label: copy.earnings,
                        ),
                        (
                          route: RouteNames.profile,
                          icon: Icons.person_outline_rounded,
                          label: copy.profile,
                        ),
                      ];
                  final selectedIndex = currentIndex.clamp(
                    0,
                    destinations.length - 1,
                  );
                  return NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      if (index == selectedIndex) return;
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        destinations[index].route,
                        (route) => route.isFirst,
                      );
                    },
                    labelTextStyle: copy.isFrench
                        ? WidgetStateProperty.resolveWith((states) {
                            final base =
                                theme.textTheme.labelMedium ??
                                const TextStyle();
                            final color = states.contains(WidgetState.selected)
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant;
                            return base.copyWith(fontSize: 10.5, color: color);
                          })
                        : null,
                    destinations: [
                      for (final destination in destinations)
                        NavigationDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.icon),
                          label: destination.label,
                        ),
                    ],
                  );
                },
              ),
            ),
      ),
    );
  }
}
