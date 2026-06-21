import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_profile.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/menu_tile.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DriverAppBar(),
    body: SafeArea(
      top: false,
      child: ValueListenableBuilder<DriverProfile>(
        valueListenable: DriverProfileService.instance.profile,
        builder: (context, profile, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 64,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(profile.phone),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.warning,
                              ),
                              Text(
                                ' ${profile.rating}',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.directions_car_rounded,
                                color: AppColors.primary,
                              ),
                              Text(
                                ' ${profile.totalTrips}',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(label: 'Online'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    MenuTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.editProfile),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle Information',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.vehicles),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.description_outlined,
                      title: 'Documents',
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.vehicleDocuments,
                      ),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.diamond_outlined,
                      title: 'Subscription',
                      trailing: const StatusBadge(label: 'Active'),
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.subscription),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.notifications,
                      ),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.helpCenter),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.settings),
                    ),
                    const Divider(height: 1),
                    MenuTile(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Refer & Earn',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.referAndEarn),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Edit Profile',
                icon: Icons.edit_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.editProfile),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 4),
  );
}
