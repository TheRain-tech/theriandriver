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
    final theme = Theme.of(context);
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
      // NavigationDestination only accepts a plain String label, with no
      // per-item overflow/FittedBox control (Flutter's NavigationBar paints
      // it as Text(label, style: textStyle), no overflow/maxLines override
      // available). French "Portefeuille" (12 chars, no spaces - can't wrap
      // at a word break like its siblings) is noticeably longer than every
      // other French label here (6-7 chars) and can overflow its 1/5-width
      // slice on narrower phones. Shrinking the label size slightly, only in
      // French, gives it room without truncating/clipping it, and leaves
      // every English label (none of which are long enough to need it) at
      // its normal size - selected/unselected colors are reproduced
      // manually since overriding labelTextStyle replaces the SDK default
      // that applies them.
      labelTextStyle: copy.isFrench
          ? WidgetStateProperty.resolveWith((states) {
              final base = theme.textTheme.labelMedium ?? const TextStyle();
              final color = states.contains(WidgetState.selected)
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant;
              return base.copyWith(fontSize: 10.5, color: color);
            })
          : null,
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
