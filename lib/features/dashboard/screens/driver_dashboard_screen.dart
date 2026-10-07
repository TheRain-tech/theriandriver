import '../../../core/localization/driver_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/env_config.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/driver_wallet_requirement.dart';
import '../../../data/models/ride_request.dart';
import '../../../data/repositories/driver_earning_repository.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/map_preview_card.dart';
import '../../shared/widgets/profile_setup_card.dart';
import '../widgets/road_alert_button.dart';
import '../widgets/ride_type_balance_row.dart';
import '../widgets/swipe_toggle_button.dart';
import '../widgets/trips_online_stat_card.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with WidgetsBindingObserver {
  final _tripRepository = DriverTripRepository();
  final _earningRepository = DriverEarningRepository();
  final _rideRepository = RideRepository();
  StreamSubscription<RideRequest?>? _requestSubscription;
  RideRequest? _incomingRequest;
  bool _changingOnlineStatus = false;
  String? _listeningDriverId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverProfileService.instance.bindAuthenticatedDriver();
    DriverProfileService.instance.profile.addListener(_syncRideListener);
    DriverProfileService.instance.fleetInfo.addListener(_syncRideListener);
    _syncRideListener();
    unawaited(LocationService.instance.showLocationPreview());
  }

  void _syncRideListener() {
    if (DriverProfileService.instance.isFleetSuspended) {
      _requestSubscription?.cancel();
      _listeningDriverId = null;
      TripService.instance.clearIncomingRequest();
      if (mounted && _incomingRequest != null) {
        setState(() => _incomingRequest = null);
      }
      return;
    }
    final profile = DriverProfileService.instance.profile.value;
    if (!EnvConfig.previewMode && !profile.canListenForRideRequests) {
      _listeningDriverId = null;
      unawaited(_requestSubscription?.cancel());
      _requestSubscription = null;
      _incomingRequest = null;
      TripService.instance.incomingRequest.value = null;
      return;
    }
    final driverId = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    if (_listeningDriverId == driverId) return;
    _listeningDriverId = driverId;
    _requestSubscription?.cancel();
    _requestSubscription = _rideRepository
        .watchIncomingRequest(driverId)
        .listen(
          (request) {
            if (!mounted) return;
            final previousRequestId = _incomingRequest?.requestId;
            if (request != null && request.requestId != previousRequestId) {
              unawaited(
                NotificationService.instance.showIncomingRideAlert(
                  request.requestId,
                ),
              );
            }
            TripService.instance.incomingRequest.value = request;
            setState(() => _incomingRequest = request);
          },
          onError: (Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  DriverCopy.current.t(
                    'Ride request listener is temporarily unavailable.',
                    "L'écoute des demandes de course est temporairement indisponible.",
                  ),
                ),
              ),
            );
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DriverProfileService.instance.restoreTrackingIfNeeded().catchError((
        Object error,
      ) {
        if (mounted) _showError(AuthService.instance.friendlyError(error));
      });
    }
  }

  Future<void> _toggleOnline() async {
    if (_changingOnlineStatus) return;
    setState(() => _changingOnlineStatus = true);
    try {
      await DriverProfileService.instance.toggleOnline();
    } on LocationAccessException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            DriverCopy.current.t('Location Required', 'Localisation requise'),
          ),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(DriverCopy.current.t('Not Now', 'Pas maintenant')),
            ),
            if (error.permanentlyDenied)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  LocationService.instance.openLocationSettings();
                },
                child: Text(
                  DriverCopy.current.t(
                    'Open Settings',
                    'Ouvrir les paramètres',
                  ),
                ),
              ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showError(AuthService.instance.friendlyError(error));
    } finally {
      if (mounted) setState(() => _changingOnlineStatus = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Bad state: ', ''))),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DriverProfileService.instance.profile.removeListener(_syncRideListener);
    DriverProfileService.instance.fleetInfo.removeListener(_syncRideListener);
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildMapFirstDashboard(context);

  Widget _buildMapFirstDashboard(BuildContext context) {
    return Scaffold(
      appBar: DriverAppBar(
        showFullHeader: true,
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.notifications),
            icon: const Badge(child: Icon(Icons.notifications_outlined)),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<DriverProfile>(
          valueListenable: DriverProfileService.instance.profile,
          builder: (context, profile, _) => LayoutBuilder(
            builder: (context, constraints) {
              final l = DriverCopy.of(context);
              // Collapsed sheet shows only the drag handle, greeting row and
              // swipe toggle; everything else is revealed by pulling up.
              const collapsedContentHeight = 190.0;
              final minFraction = constraints.maxHeight <= 0
                  ? 0.25
                  : (collapsedContentHeight / constraints.maxHeight).clamp(
                      0.15,
                      0.5,
                    );
              return Stack(
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
                    child: SafeArea(
                      bottom: false,
                      child: RoadAlertButton(),
                    ),
                  ),
                  DraggableScrollableSheet(
                    initialChildSize: minFraction,
                    minChildSize: minFraction,
                    maxChildSize: 0.88,
                    snap: true,
                    snapSizes: [minFraction, 0.88],
                    builder: (context, controller) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundFor(context),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 16,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.borderFor(context),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DriverCopy.of(
                                          context,
                                        ).t('Good Morning,', 'Bonjour,'),
                                        style: TextStyle(
                                          color: AppColors.textSecondaryFor(
                                            context,
                                          ),
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        profile.fullName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: _statusLabel(profile, l),
                                  tone: _statusTone(profile),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SwipeToggleButton(
                              onToggle: _toggleOnline,
                              enabled:
                                  !_changingOnlineStatus &&
                                  _blockedReason(profile) == null,
                            ),
                            const SizedBox(height: 20),
                            AppCard(
                              color: _statusTone(profile) == BadgeTone.success
                                  ? AppColors.successSoftFor(context)
                                  : AppColors.primarySoftFor(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      IconWell(
                                        icon:
                                            profile.onlineStatus ==
                                                DriverOnlineStatus.offline
                                            ? Icons.power_settings_new_rounded
                                            : Icons.radar_rounded,
                                        size: 58,
                                        color:
                                            _statusTone(profile) ==
                                                BadgeTone.success
                                            ? AppColors.success
                                            : AppColors.primary,
                                        background:
                                            _statusTone(profile) ==
                                                BadgeTone.success
                                            ? AppColors.successSoftFor(context)
                                            : AppColors.surfaceFor(context),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _statusLabel(profile, l),
                                              style: TextStyle(
                                                color: AppColors.textPrimaryFor(
                                                  context,
                                                ),
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(_statusDescription(profile, l)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_blockedReason(profile) != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _blockedReasonDisplay(_blockedReason(profile)!, l),
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_blockedReason(profile) ==
                                        'commission_wallet_empty') ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final result =
                                                await Navigator.pushNamed(
                                                  context,
                                                  RouteNames.topUp,
                                                );
                                            if (result == true) {
                                              setState(() {});
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            l.t(
                                              'Top Up commission balance',
                                              'Recharger le solde de commission',
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: const BorderSide(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_blockedReason(profile) ==
                                        'vehicle_inactive') ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final result =
                                                await Navigator.pushNamed(
                                                  context,
                                                  RouteNames.vehicles,
                                                );
                                            if (result == true) {
                                              setState(() {});
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.directions_car_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            l.t(
                                              'Complete vehicle details',
                                              'Compléter les détails du véhicule',
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: const BorderSide(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                            if (profile.verificationStatus !=
                                DriverVerificationStatus.approved) ...[
                              const SizedBox(height: 14),
                              ProfileSetupCard(
                                profile: profile,
                                asButton: true,
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (_incomingRequest != null) ...[
                              AppCard(
                                color: AppColors.primarySoft,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  RouteNames.rideRequest,
                                ),
                                child: Row(
                                  children: [
                                    const IconWell(
                                      icon: Icons.near_me_rounded,
                                      size: 54,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l.t('New Ride Request', 'Nouvelle demande de course'),
                                            style: TextStyle(
                                              color: AppColors.navy,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            _incomingRequest!
                                                .pickupLocation
                                                .address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            FutureBuilder(
                              future: _earningRepository.getEarnings(
                                period: 'Daily',
                              ),
                              builder: (context, snapshot) {
                                final earnings = snapshot.data;
                                final today =
                                    earnings == null || earnings.isEmpty
                                    ? null
                                    : earnings.first;
                                return Column(
                                  children: [
                                    AppCard(
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        RouteNames.earnings,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l.t("Today's Earnings", 'Gains du jour'),
                                                  style: TextStyle(
                                                    color: AppColors.slate,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  CurrencyFormatter.format(
                                                    today?.total ?? 0,
                                                  ),
                                                  style: const TextStyle(
                                                    color: AppColors.navy,
                                                    fontSize: 31,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const IconWell(
                                            icon: Icons
                                                .stacked_line_chart_rounded,
                                            size: 62,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TripsOnlineStatCard(
                                      tripsValue: l.t(
                                        '${profile.totalTrips} Trips',
                                        '${profile.totalTrips} courses',
                                      ),
                                      onlineTimeValue: _formatOnlineTime(
                                        today?.onlineMinutes ?? 0,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            RideTypeBalanceRow(profile: profile),
                            const SizedBox(height: 14),
                            AppCard(
                              onTap: () => Navigator.pushNamed(
                                context,
                                RouteNames.subscription,
                              ),
                              child: Row(
                                children: [
                                  const IconWell(
                                    icon: Icons.diamond_outlined,
                                    size: 56,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(l.t('Subscription', 'Abonnement')),
                                        Text(
                                          l.t('Premium', 'Premium'),
                                          style: TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          l.t(
                                            'Valid until 20 Jun 2026',
                                            'Valide jusqu\'au 20 juin 2026',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(label: l.t('Active', 'Actif')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SectionHeader(
                              title: l.t('Today\'s Trips', 'Courses d\'aujourd\'hui'),
                              actionLabel: l.t('See all', 'Voir tout'),
                              onAction: () => Navigator.pushNamed(
                                context,
                                RouteNames.trips,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<List<DriverTrip>>(
                              future: _tripRepository.getTrips(),
                              builder: (context, snapshot) {
                                final trips =
                                    snapshot.data ?? const <DriverTrip>[];
                                return AppCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < trips.take(3).length;
                                        i++
                                      ) ...[
                                        ListTile(
                                          onTap: () => Navigator.pushNamed(
                                            context,
                                            RouteNames.tripDetails,
                                            arguments: trips[i].id,
                                          ),
                                          leading: const IconWell(
                                            icon: Icons.location_on_rounded,
                                            size: 42,
                                          ),
                                          title: Text(
                                            trips[i].pickup,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.navy,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: Text(trips[i].dropOff),
                                          trailing: Text(
                                            CurrencyFormatter.format(
                                              trips[i].fare,
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.navy,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (i < 2) const Divider(height: 1),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _incomingRequest == null
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      RouteNames.rideRequest,
                                    ),
                              icon: const Icon(Icons.near_me_rounded),
                              label: Text(
                                _incomingRequest == null
                                    ? l.t(
                                        'Waiting for Ride Requests',
                                        'En attente de demandes de course',
                                      )
                                    : l.openIncomingRide,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
    );
  }

  String _statusLabel(DriverProfile profile, DriverCopy l) {
    if (profile.currentRideId != null) return l.t('On Trip', 'En course');
    if (profile.onlineStatus == DriverOnlineStatus.busy) return l.t('Busy', 'Occupé');
    final blocked = _blockedReason(profile);
    if (blocked != null) {
      if (blocked == 'commission_wallet_empty') return l.t('Low Balance', 'Solde faible');
      return l.t('Approval Required', 'Approbation requise');
    }
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return _incomingRequest == null
          ? l.t('Waiting for request', 'En attente de demande')
          : l.t('Ride Request', 'Demande de course');
    }
    return l.t('Offline', 'Hors ligne');
  }

  BadgeTone _statusTone(DriverProfile profile) {
    if (profile.currentRideId != null ||
        profile.onlineStatus == DriverOnlineStatus.busy) {
      return BadgeTone.warning;
    }
    if (_blockedReason(profile) != null) return BadgeTone.danger;
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return BadgeTone.success;
    }
    return BadgeTone.neutral;
  }

  String _statusDescription(DriverProfile profile, DriverCopy l) {
    if (profile.currentRideId != null) {
      return l.t('Complete active trip first.', 'Terminez la course active d\'abord.');
    }
    final blocked = _blockedReason(profile);
    if (blocked != null) return _blockedReasonDisplay(blocked, l);
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return l.t(
        'You are online and visible to riders nearby.',
        'Vous êtes en ligne et visible par les passagers à proximité.',
      );
    }
    return l.t(
      'Go online when you are ready to receive rides.',
      'Passez en ligne lorsque vous êtes prêt à recevoir des courses.',
    );
  }

  // Stable, never-translated reason codes - driven by profile state, not display copy. Several
  // call sites compare this value directly (.contains/== checks deciding which follow-up action
  // button to show), so translating it in place would silently break those checks for a French
  // driver. _blockedReasonDisplay below is the only place that turns a code into real text.
  String? _blockedReason(DriverProfile profile) {
    if (profile.isSuspended) {
      return 'account_restricted';
    }
    if (profile.verificationStatus != DriverVerificationStatus.approved) {
      return profile.verificationStatus == DriverVerificationStatus.pending
          ? 'awaiting_approval'
          : 'complete_verification';
    }
    if (!profile.isAccountActive) {
      return 'awaiting_approval';
    }
    // canGoOnline is deliberately not checked here - see driver_repository.dart#setOnline's
    // comment on the same field. canReceiveRides is the real, admin-owned approval flag.
    if (!profile.canReceiveRides) {
      return 'approval_required';
    }
    // Only a driver who pays commission from their own wallet (own vehicle) needs a balance here. A
    // TheRain-managed driver never does, and a fleet driver's wallet is the fleet owner's - the server
    // reports that block (with the reason) when they try to go online.
    if (walletCategoryOf(profile) == DriverWalletCategory.ownVehicle &&
        (profile.commissionWalletStatus == 'empty' ||
            profile.commissionWalletStatus == 'blocked')) {
      return 'commission_wallet_empty';
    }
    if (profile.vehicleModel.isEmpty || profile.vehiclePlateNumber.isEmpty) {
      return 'vehicle_inactive';
    }
    return null;
  }

  String _blockedReasonDisplay(String reason, DriverCopy l) {
    return switch (reason) {
      'account_restricted' => l.t('Account restricted', 'Compte restreint'),
      'awaiting_approval' => l.t('Awaiting approval', 'En attente d\'approbation'),
      'complete_verification' => l.t('Complete verification', 'Terminer la vérification'),
      'approval_required' => l.t('Approval required', 'Approbation requise'),
      'commission_wallet_empty' => l.t(
          'Add funds to your TheRain wallet to go online and accept rides.',
          'Ajoutez des fonds à votre portefeuille TheRain pour vous mettre en ligne et accepter des courses.',
        ),
      'vehicle_inactive' => l.t('Vehicle inactive', 'Véhicule inactif'),
      _ => reason,
    };
  }

  String _formatOnlineTime(int minutes) {
    final l = DriverCopy.current;
    if (minutes <= 0) return l.t('0h 0m', '0h 0min');
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return l.t('${remainingMinutes}m', '${remainingMinutes}min');
    return l.t('${hours}h ${remainingMinutes}m', '${hours}h ${remainingMinutes}min');
  }
}
