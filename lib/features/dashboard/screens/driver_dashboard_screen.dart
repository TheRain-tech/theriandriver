import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/ride_request.dart';
import '../../../data/repositories/driver_earning_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/map_preview_card.dart';
import '../../shared/widgets/stat_card.dart';

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
    final driverId = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    if (_listeningDriverId == driverId) return;
    _listeningDriverId = driverId;
    _requestSubscription?.cancel();
    _requestSubscription =
        _rideRepository.watchIncomingRequest(driverId).listen(
      (request) {
        if (!mounted) return;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DriverAppBar(
        showOnline: true,
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.notifications),
            icon: const Badge(child: Icon(Icons.notifications_outlined)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<DriverProfile>(
          valueListenable: DriverProfileService.instance.profile,
          builder: (context, profile, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            icon: profile.onlineStatus ==
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
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _changingOnlineStatus ? null : _toggleOnline,
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
                  onTap: () => Navigator.pushNamed(context, RouteNames.fuel),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          IconWell(icon: Icons.local_gas_station_outlined),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Fuel Level',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '78%',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: .78,
                        minHeight: 9,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ],
                  ),
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
      return 'You are visible to riders nearby.';
    }
    return 'Go online when you are ready to receive rides.';
  }

  String _actionLabel(DriverProfile profile) {
    if (profile.currentRideId != null) return 'Complete active trip first';
    if (profile.onlineStatus == DriverOnlineStatus.online) {
      return "You're Online";
    }
    return 'Go Online';
  }

  String? _blockedReason(DriverProfile profile) {
    if (profile.accountStatus == 'suspended' ||
        profile.accountStatus == 'blocked') {
      return 'Account restricted';
    }
    if (profile.verificationStatus != DriverVerificationStatus.approved) {
      return profile.verificationStatus == DriverVerificationStatus.pending
          ? 'Awaiting approval'
          : 'Complete verification';
    }
    if (profile.accountStatus != 'active') return 'Awaiting approval';
    if (!profile.canGoOnline || !profile.canReceiveRides) {
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

  String _formatOnlineTime(int minutes) {
    if (minutes <= 0) return '0h 0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '${remainingMinutes}m';
    return '${hours}h ${remainingMinutes}m';
  }
}
