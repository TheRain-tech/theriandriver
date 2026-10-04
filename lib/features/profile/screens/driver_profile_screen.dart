import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
        builder: (context, profile, _) {
          final l = DriverCopy.of(context);
          return SingleChildScrollView(
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
                      label: _accountTypeLabel(profile, l),
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
                          ' ${profile.totalTrips} ${l.t('trips', 'courses')}',
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
                      label: l.t('Driver Account', 'Compte chauffeur'),
                      value: _accountTypeLabel(profile, l),
                    ),
                    if (profile.driverType != 'individual') ...[
                      Divider(height: 24),
                      LabeledValue(
                        icon: Icons.business_outlined,
                        label: l.t('Fleet', 'Flotte'),
                        value: profile.fleetName ?? l.t('Assigned fleet', 'Flotte assignée'),
                      ),
                    ],
                    Divider(height: 24),
                    LabeledValue(
                      icon: Icons.account_balance_wallet_outlined,
                      label: l.t('Commission Paid By', 'Commission payée par'),
                      value: profile.commissionWalletOwnerType == 'fleet'
                          ? l.t('Fleet', 'Flotte')
                          : l.t('Driver', 'Chauffeur'),
                    ),
                    Divider(height: 24),
                    LabeledValue(
                      icon: Icons.payments_outlined,
                      label: l.t('Payout Goes To', 'Le paiement va à'),
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
                      title: l.t('Profile', 'Profil'),
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.editProfile),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.directions_car_outlined,
                      title: l.t('Vehicle Information', 'Informations du véhicule'),
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.vehicles),
                    ),
                    Divider(height: 1),
                    if (profile.isFleetDriver) ...[
                      MenuTile(
                        icon: Icons.handshake_outlined,
                        title: l.t('Fleet Agreement', 'Accord de flotte'),
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.fleetAgreement,
                        ),
                      ),
                      Divider(height: 1),
                      MenuTile(
                        icon: Icons.flag_outlined,
                        title: l.t('Report Fleet', 'Signaler la flotte'),
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
                        title: l.t('Request Payment', 'Demander un paiement'),
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.paymentRequest,
                        ),
                      ),
                      Divider(height: 1),
                      MenuTile(
                        icon: Icons.receipt_long_outlined,
                        title: l.t('Payment History', 'Historique des paiements'),
                        onTap: () => Navigator.pushNamed(
                          context,
                          RouteNames.paymentHistory,
                        ),
                      ),
                      Divider(height: 1),
                    ],
                    MenuTile(
                      icon: Icons.description_outlined,
                      title: l.t('Documents', 'Documents'),
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.vehicleDocuments,
                      ),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.diamond_outlined,
                      title: l.t('Subscription', 'Abonnement'),
                      trailing: StatusBadge(label: l.t('Active', 'Actif')),
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.subscription),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.notifications_outlined,
                      title: l.notifications,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.notifications,
                      ),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.help_outline_rounded,
                      title: l.helpCenter,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.helpCenter),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.settings_outlined,
                      title: l.settings,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.settings),
                    ),
                    Divider(height: 1),
                    MenuTile(
                      icon: Icons.card_giftcard_outlined,
                      title: l.t('Refer & Earn', 'Parrainer et gagner'),
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.referAndEarn),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              PrimaryButton(
                label: l.t('Edit Profile', 'Modifier le profil'),
                icon: Icons.edit_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.editProfile),
              ),
            ],
          ),
          );
        },
      ),
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 4),
  );

  String _accountTypeLabel(DriverProfile profile, DriverCopy l) {
    return switch (profile.driverType) {
      'fleet' => l.t('Fleet Driver', 'Chauffeur de flotte'),
      'enterprise' => l.t('Enterprise Driver', 'Chauffeur d\'entreprise'),
      _ => l.t('Individual Driver', 'Chauffeur indépendant'),
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

  String _statusLabel(String? status, DriverCopy l) {
    return switch (status) {
      'Verified' => l.t('Verified', 'Vérifié'),
      'Suspended' => l.t('Suspended', 'Suspendu'),
      'Rejected' => l.t('Rejected', 'Rejeté'),
      _ => l.t('Pending', 'En attente'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return AppCard(
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
                fleetInfo?.fleetName ?? profile.fleetName ?? l.t('Fleet Partner', 'Partenaire de flotte'),
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            StatusBadge(
              label: _statusLabel(fleetInfo?.displayStatus, l),
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
            LabeledValue(label: l.t('Company Name', 'Nom de l\'entreprise'), value: fleetInfo!.companyName),
            SizedBox(height: 12),
          ],
          if (fleetInfo!.email != null) ...[
            LabeledValue(label: l.t('Fleet Email', 'E-mail de la flotte'), value: fleetInfo!.email!),
            SizedBox(height: 12),
          ],
          if (fleetInfo!.phoneNumber != null) ...[
            LabeledValue(label: l.t('Fleet Phone', 'Téléphone de la flotte'), value: fleetInfo!.phoneNumber!),
            SizedBox(height: 12),
          ],
          if (fleetInfo!.address != null)
            LabeledValue(label: l.t('Fleet Address', 'Adresse de la flotte'), value: fleetInfo!.address!),
        ],
      ],
    ),
    );
  }
}

/// TheRain-direct drivers see this instead of Fleet Information/Agreement/
/// Report Fleet, with zero report functionality shown.
class _CompanyDriverBanner extends StatelessWidget {
  const _CompanyDriverBanner();

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return AppCard(
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
                l.t('Company Driver', 'Chauffeur d\'entreprise'),
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 3),
              Text(
                l.t('TheRain Official Driver', 'Chauffeur officiel TheRain'),
                style: TextStyle(color: AppColors.textSecondaryFor(context)),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}
