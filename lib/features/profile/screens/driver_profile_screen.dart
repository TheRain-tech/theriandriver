import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/fleet_info.dart';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primarySoftFor(context),
                          backgroundImage:
                              profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child:
                              profile.avatarUrl == null ||
                                  profile.avatarUrl!.isEmpty
                              ? Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 46,
                                )
                              : null,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                style: TextStyle(
                                  color: AppColors.textPrimaryFor(context),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                profile.phone,
                                style: TextStyle(
                                  color: AppColors.textSecondaryFor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    StatusBadge(
                      label: _accountTypeLabel(profile),
                      tone: profile.driverType == 'individual'
                          ? BadgeTone.info
                          : BadgeTone.warning,
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: AppColors.warning),
                        Text(
                          ' ${profile.rating}',
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 22),
                        Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.primary,
                        ),
                        Text(
                          ' ${profile.totalTrips} trips',
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabeledValue(
                      icon: Icons.badge_outlined,
                      label: 'Driver Account',
                      value: _accountTypeLabel(profile),
                    ),
                    if (profile.driverType != 'individual') ...[
                      Divider(height: 24),
                      LabeledValue(
                        icon: Icons.business_outlined,
                        label: 'Fleet',
                        value: profile.fleetName ?? 'Assigned fleet',
                      ),
                    ],
                    Divider(height: 24),
                    LabeledValue(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Commission Paid By',
                      value: profile.commissionWalletOwnerType == 'fleet'
                          ? 'Fleet'
                          : 'Driver',
                    ),
                    Divider(height: 24),
                    LabeledValue(
                      icon: Icons.payments_outlined,
                      label: 'Payout Goes To',
                      value: _capitalize(profile.payoutOwner),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              // Driver Identification: automatically resolved from the
              // driver's fleetId (see DriverProfileService._syncFleetInfo) —
              // no manual selection anywhere in this app.
              ValueListenableBuilder<FleetInfo?>(
                valueListenable: DriverProfileService.instance.fleetInfo,
                builder: (context, fleetInfo, _) => profile.isFleetDriver
                    ? _FleetInfoCard(profile: profile, fleetInfo: fleetInfo)
                    : const _CompanyDriverBanner(),
              ),
              SizedBox(height: 18),
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
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle Information',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.vehicles),
                    ),
                    Divider(height: 1),
                    if (profile.isFleetDriver) ...[
                      MenuTile(
                        icon: Icons.handshake_outlined,
                        title: 'Fleet Agreement',
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.fleetAgreement,
                        ),
                      ),
                      Divider(height: 1),
                      MenuTile(
                        icon: Icons.flag_outlined,
                        title: 'Report Fleet',
                        danger: true,
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.reportFleet,
                        ),
                      ),
                      Divider(height: 1),
                    ] else ...[
                      MenuTile(
                        icon: Icons.request_quote_outlined,
                        title: 'Request Payment',
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.paymentRequest,
                        ),
                      ),
                      Divider(height: 1),
                      MenuTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Payment History',
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.paymentHistory,
                        ),
                      ),
                      Divider(height: 1),
                    ],
                    MenuTile(
                      icon: Icons.description_outlined,
                      title: 'Documents',
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.vehicleDocuments,
                      ),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.diamond_outlined,
                      title: 'Subscription',
                      trailing: const StatusBadge(label: 'Active'),
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.subscription),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.notifications,
                      ),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.helpCenter),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.settings),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Refer & Earn',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.referAndEarn),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
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

  String _accountTypeLabel(DriverProfile profile) {
    return switch (profile.driverType) {
      'fleet' => 'Fleet Driver',
      'enterprise' => 'Enterprise Driver',
      _ => 'Individual Driver',
    };
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

/// Fleet Information section (Fleet Logo, Display Name, Company Name, Fleet
/// Email, Fleet Phone, Fleet Address, Fleet Status) — shown only for
/// fleet-linked drivers, matching the existing profile screen's design
/// system (AppCard/LabeledValue/StatusBadge).
class _FleetInfoCard extends StatelessWidget {
  const _FleetInfoCard({required this.profile, required this.fleetInfo});

  final DriverProfile profile;
  final FleetInfo? fleetInfo;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primarySoftFor(context),
              backgroundImage:
                  fleetInfo?.logoUrl != null && fleetInfo!.logoUrl!.isNotEmpty
                  ? NetworkImage(fleetInfo!.logoUrl!)
                  : null,
              child: fleetInfo?.logoUrl == null || fleetInfo!.logoUrl!.isEmpty
                  ? Icon(Icons.local_shipping_rounded, color: AppColors.primary)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                fleetInfo?.fleetName ?? profile.fleetName ?? 'Fleet Partner',
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            StatusBadge(
              label: fleetInfo?.displayStatus ?? 'Pending',
              tone: switch (fleetInfo?.displayStatus) {
                'Verified' => BadgeTone.success,
                'Suspended' || 'Rejected' => BadgeTone.danger,
                _ => BadgeTone.warning,
              },
            ),
          ],
        ),
        if (fleetInfo != null) ...[
          Divider(height: 28),
          if (fleetInfo!.companyName.isNotEmpty) ...[
            LabeledValue(label: 'Company Name', value: fleetInfo!.companyName),
            SizedBox(height: 12),
          ],
          if (fleetInfo!.email != null) ...[
            LabeledValue(label: 'Fleet Email', value: fleetInfo!.email!),
            SizedBox(height: 12),
          ],
          if (fleetInfo!.phoneNumber != null) ...[
            LabeledValue(label: 'Fleet Phone', value: fleetInfo!.phoneNumber!),
            SizedBox(height: 12),
          ],
          if (fleetInfo!.address != null)
            LabeledValue(label: 'Fleet Address', value: fleetInfo!.address!),
        ],
      ],
    ),
  );
}

/// TheRain-direct drivers see this instead of Fleet Information/Agreement/
/// Report Fleet, with zero report functionality shown.
class _CompanyDriverBanner extends StatelessWidget {
  const _CompanyDriverBanner();

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.primarySoftFor(context),
    borderColor: AppColors.primary,
    child: Row(
      children: [
        IconWell(icon: Icons.verified_rounded, background: Colors.white),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Driver',
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'TheRain Official Driver',
                style: TextStyle(color: AppColors.textSecondaryFor(context)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
