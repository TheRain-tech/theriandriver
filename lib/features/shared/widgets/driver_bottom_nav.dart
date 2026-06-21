import 'package:flutter/material.dart';

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
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.monetization_on_outlined),
          selectedIcon: Icon(Icons.monetization_on_rounded),
          label: 'Earnings',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car_rounded),
          label: 'Trips',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Wallet',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}
