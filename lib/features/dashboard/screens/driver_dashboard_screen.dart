import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/ride_request.dart';
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
  final _rideRepository = RideRepository();
  StreamSubscription<RideRequest?>? _requestSubscription;
  RideRequest? _incomingRequest;
  bool _changingOnlineStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverProfileService.instance.bindAuthenticatedDriver();
    final uid = AuthService.instance.currentUserId ?? 'preview-driver';
    _requestSubscription = _rideRepository
        .watchIncomingRequest(uid)
        .listen(
          (request) {
            if (!mounted) return;
            TripService.instance.incomingRequest.value = request;
            setState(() => _incomingRequest = request);
          },
          onError: (Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ride request listener: $error')),
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
        if (mounted) _showError(error.toString());
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
      if (mounted) _showError(error.toString());
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
                    InkWell(
                      onTap: _changingOnlineStatus ? null : _toggleOnline,
                      child: StatusBadge(
                        label: profile.onlineStatus == DriverOnlineStatus.online
                            ? 'Online'
                            : 'Offline',
                        tone: profile.onlineStatus == DriverOnlineStatus.online
                            ? BadgeTone.success
                            : BadgeTone.neutral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                              CurrencyFormatter.format(125600),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.schedule_rounded,
                        label: 'Online Time',
                        value: '06:45',
                        suffix: 'Hrs',
                      ),
                    ),
                  ],
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
}
