import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../router/route_names.dart';

class DriverBottomNav extends StatelessWidget {
  const DriverBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const routes = [
    RouteNames.dashboard,
    RouteNames.earnings,
    RouteNames.trips,
    RouteNames.wallet,
    RouteNames.profile,
  ];

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          routes[index],
          (route) => route.isFirst,
        );
      },
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: copy.home,
        ),
        NavigationDestination(
          icon: Icon(Icons.monetization_on_outlined),
          selectedIcon: Icon(Icons.monetization_on_rounded),
          label: copy.earnings,
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car_rounded),
          label: copy.trips,
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: copy.wallet,
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: copy.profile,
        ),
      ],
    );
  }
}
