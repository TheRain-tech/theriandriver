import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/env_config.dart';
import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/ride_request.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/map_preview_card.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with WidgetsBindingObserver {
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
              const SnackBar(
                content: Text(
                  'Ride request listener is temporarily unavailable.',
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
          title: const Text('Location Required'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not Now'),
            ),
            if (error.permanentlyDenied)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  LocationService.instance.openLocationSettings();
                },
                child: const Text('Open Settings'),
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
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<DriverProfile>(
          valueListenable: DriverProfileService.instance.profile,
          builder: (context, profile, _) {
            final copy = DriverCopy.of(context);
            final colors = Theme.of(context).colorScheme;
            return Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) => MapPreviewCard(
                      height: constraints.maxHeight,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 18,
                  right: 18,
                  child: Row(
                    children: [
                      Material(
                        color: colors.surface,
                        elevation: 5,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: copy.profile,
                          onPressed: () =>
                              Navigator.pushNamed(context, RouteNames.profile),
                          icon: const Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          color: colors.surface,
                          elevation: 5,
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              profile.fullName.isEmpty
                                  ? copy.driverDashboard
                                  : profile.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: colors.surface,
                        elevation: 5,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: copy.notifications,
                          onPressed: () => Navigator.pushNamed(
                            context,
                            RouteNames.notifications,
                          ),
                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.36,
                  minChildSize: 0.25,
                  maxChildSize: 0.88,
                  builder: (context, scrollController) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x260A1A33),
                          blurRadius: 24,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.outlineVariant,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            copy.goodMorning,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                profile.onlineStatus ==
                                        DriverOnlineStatus.online
                                    ? Icons.radar_rounded
                                    : Icons.power_settings_new_rounded,
                                color: _statusTone(profile) == BadgeTone.success
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _statusLabel(profile),
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(_statusDescription(profile)),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                label:
                                    profile.onlineStatus ==
                                        DriverOnlineStatus.online
                                    ? copy.online
                                    : copy.offline,
                                tone: _statusTone(profile),
                              ),
                            ],
                          ),
                          if (_blockedReason(profile) != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _blockedReason(profile)!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed:
                                _changingOnlineStatus ||
                                    (_blockedReason(profile) != null &&
                                        profile.onlineStatus ==
                                            DriverOnlineStatus.offline)
                                ? null
                                : _toggleOnline,
                            icon: Icon(
                              profile.onlineStatus == DriverOnlineStatus.offline
                                  ? Icons.play_arrow_rounded
                                  : Icons.stop_rounded,
                            ),
                            label: Text(_actionLabel(profile)),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 17),
                            ),
                          ),
                          if (_incomingRequest != null) ...[
                            const SizedBox(height: 16),
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
                                    size: 52,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          copy.newRideRequest,
                                          style: const TextStyle(
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
                                  const Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                RouteNames.rideRequest,
                              ),
                              icon: const Icon(Icons.near_me_rounded),
                              label: Text(copy.openIncomingRide),
                            ),
                          ],
                          const SizedBox(height: 16),
                          AppCard(
                            onTap: () => Navigator.pushNamed(
                              context,
                              RouteNames.earnings,
                            ),
                            child: Row(
                              children: [
                                IconWell(
                                  icon: Icons.stacked_line_chart_rounded,
                                  size: 52,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        copy.todayEarnings,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        copy.viewEarnings,
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded),
                              ],
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
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
    );
  }

  /* Retired pre-map-first dashboard. Kept non-executable during rollout. */
  /*
                          const Text(
                            'Good Morning,',
                            style: TextStyle(
                              color: AppColors.slate,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            profile.fullName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: _statusLabel(profile),
                      tone: _statusTone(profile),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (profile.verificationStatus !=
                    DriverVerificationStatus.approved) ...[
                  _SetupReminder(profile: profile),
                  const SizedBox(height: 14),
                ],
                AppCard(
                  color: _statusTone(profile) == BadgeTone.success
                      ? AppColors.successSoft
                      : AppColors.primarySoft,
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
                            color: _statusTone(profile) == BadgeTone.success
                                ? AppColors.success
                                : AppColors.primary,
                            background:
                                _statusTone(profile) == BadgeTone.success
                                ? AppColors.successSoft
                                : Colors.white,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusLabel(profile),
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(_statusDescription(profile)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_blockedReason(profile) != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _blockedReason(profile)!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_blockedReason(
                          profile,
                        )!.contains('commission')) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.pushNamed(
                                  context,
                                  RouteNames.topUp,
                                );
                                if (result == true) setState(() {});
                              },
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Top Up commission balance'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                        if (_blockedReason(profile) == 'Vehicle inactive') ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.pushNamed(
                                  context,
                                  RouteNames.vehicles,
                                );
                                if (result == true) setState(() {});
                              },
                              icon: const Icon(
                                Icons.directions_car_outlined,
                                size: 18,
                              ),
                              label: const Text('Complete vehicle details'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed:
                            _changingOnlineStatus ||
                                (_blockedReason(profile) != null &&
                                    profile.onlineStatus ==
                                        DriverOnlineStatus.offline)
                            ? null
                            : _toggleOnline,
                        icon: Icon(
                          profile.onlineStatus == DriverOnlineStatus.offline
                              ? Icons.play_arrow_rounded
                              : Icons.stop_rounded,
                        ),
                        label: Text(_actionLabel(profile)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const MapPreviewCard(height: 230),
                const SizedBox(height: 14),
                if (_incomingRequest != null) ...[
                  AppCard(
                    color: AppColors.primarySoft,
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.rideRequest),
                    child: Row(
                      children: [
                        const IconWell(icon: Icons.near_me_rounded, size: 54),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'New Ride Request',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _incomingRequest!.pickupLocation.address,
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
                  future: _earningRepository.getEarnings(period: 'Daily'),
                  builder: (context, snapshot) {
                    final earnings = snapshot.data;
                    final today = earnings == null || earnings.isEmpty
                        ? null
                        : earnings.first;
                    return Column(
                      children: [
                        AppCard(
                          onTap: () =>
                              Navigator.pushNamed(context, RouteNames.earnings),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Today's Earnings",
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
                                icon: Icons.stacked_line_chart_rounded,
                                size: 62,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                icon: Icons.work_outline_rounded,
                                label: 'Trips Completed',
                                value: '${profile.totalTrips}',
                                suffix: 'Trips',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                icon: Icons.schedule_rounded,
                                label: 'Online Time',
                                value: _formatOnlineTime(
                                  today?.onlineMinutes ?? 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                AppCard(
                  onTap: () =>
                      Navigator.pushNamed(context, RouteNames.subscription),
                  child: const Row(
                    children: [
                      IconWell(icon: Icons.diamond_outlined, size: 56),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subscription'),
                            Text(
                              'Premium',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Valid until 20 Jun 2026'),
                          ],
                        ),
                      ),
                      StatusBadge(label: 'Active'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: "Today's Trips",
                  actionLabel: 'See all',
                  onAction: () =>
                      Navigator.pushNamed(context, RouteNames.trips),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<DriverTrip>>(
                  future: _tripRepository.getTrips(),
                  builder: (context, snapshot) {
                    final trips = snapshot.data ?? const <DriverTrip>[];
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < trips.take(3).length; i++) ...[
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
                                CurrencyFormatter.format(trips[i].fare),
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
                        ? 'Waiting for Ride Requests'
                        : 'Open Incoming Ride',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
    );
  }

  */
  String _statusLabel(DriverProfile profile) {
    if (profile.currentRideId != null) return 'On Trip';
    if (profile.onlineStatus == DriverOnlineStatus.busy) return 'Busy';
    final blocked = _blockedReason(profile);
    if (blocked != null) {
      if (blocked.contains('commission')) return 'Low Balance';
      return 'Approval Required';
    }
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return _incomingRequest == null ? 'Waiting for request' : 'Ride Request';
    }
    return 'Offline';
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

  String _statusDescription(DriverProfile profile) {
    if (profile.currentRideId != null) return 'Complete active trip first.';
    final blocked = _blockedReason(profile);
    if (blocked != null) return blocked;
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return 'You are online and visible to riders nearby.';
    }
    return 'Go online when you are ready to receive rides.';
  }

  String _actionLabel(DriverProfile profile) {
    if (profile.currentRideId != null) return 'Complete active trip first';
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return 'Go Offline';
    }
    if (_blockedReason(profile) != null) return 'Go Online unavailable';
    return 'Go Online';
  }

  String? _blockedReason(DriverProfile profile) {
    if (profile.isSuspended) {
      return 'Account restricted';
    }
    if (profile.verificationStatus != DriverVerificationStatus.approved) {
      return profile.verificationStatus == DriverVerificationStatus.pending
          ? 'Awaiting approval'
          : 'Complete verification';
    }
    if (!profile.isAccountActive) {
      return 'Awaiting approval';
    }
    // canGoOnline is deliberately not checked here - see driver_repository.dart#setOnline's
    // comment on the same field. canReceiveRides is the real, admin-owned approval flag.
    if (!profile.canReceiveRides) {
      return 'Approval required';
    }
    if (profile.commissionWalletStatus == 'empty' ||
        profile.commissionWalletStatus == 'blocked') {
      return 'Top up your commission balance to receive rides.';
    }
    if (profile.vehicleModel.isEmpty || profile.vehiclePlateNumber.isEmpty) {
      return 'Vehicle inactive';
    }
    return null;
  }
}

/*
class _SetupReminder extends StatelessWidget {
  const _SetupReminder({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final pending =
        profile.verificationStatus == DriverVerificationStatus.pending;
    final needsChanges =
        profile.verificationStatus == DriverVerificationStatus.rejected ||
        profile.verificationStatus ==
            DriverVerificationStatus.resubmissionRequired;
    final title = pending
        ? 'Application under review'
        : needsChanges
        ? 'Update your driver application'
        : 'Complete your driver setup';
    final message = pending
        ? 'You can use your account while TheRain reviews your documents. Going online stays locked until approval.'
        : needsChanges
        ? 'Review the feedback and update the requested information before resubmitting.'
        : 'Add your personal, vehicle, fleet and document details to become a verified driver.';

    return AppCard(
      color: AppColors.warningSoft,
      onTap: () => Navigator.pushNamed(context, RouteNames.application),
      child: Row(
        children: [
          const IconWell(
            icon: Icons.assignment_outlined,
            color: AppColors.warning,
            background: Colors.white,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
        ],
      ),
    );
  }
}
*/
