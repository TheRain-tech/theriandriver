import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';

/// The live-trip screen a trip in [status] belongs on, or null once the trip is over (completed,
/// cancelled, missed) or not yet accepted - those belong on Trip Details instead.
String? activeTripRouteFor(TripStatus status) => switch (status) {
  TripStatus.accepted || TripStatus.goingToPickup => RouteNames.goToPickup,
  TripStatus.arrived => RouteNames.pickupConfirmed,
  TripStatus.inProgress => RouteNames.tripInProgress,
  _ => null,
};

/// Reopens the live-trip flow for [trip]. The pickup/in-progress screens read the ride from
/// TripService rather than route arguments, so it has to be seeded first - the same thing
/// AuthService does when it resumes an active ride at startup.
Future<void> openActiveTrip(BuildContext context, DriverTrip trip) async {
  final route = activeTripRouteFor(trip.status);
  if (route == null) return;
  TripService.instance.activeTrip.value = trip;
  await Navigator.pushNamed(context, route);
}

/// "Active Trip in Progress" shortcut shown above the trips list. Driven by the live driver
/// profile's currentRideId, so it appears/disappears on its own as the ride starts and ends.
class ActiveTripBanner extends StatefulWidget {
  const ActiveTripBanner({super.key});

  @override
  State<ActiveTripBanner> createState() => _ActiveTripBannerState();
}

class _ActiveTripBannerState extends State<ActiveTripBanner> {
  bool _opening = false;

  Future<void> _open(String rideId) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final trip = await RideRepository().getRide(rideId);
      if (!mounted) return;
      if (trip == null || activeTripRouteFor(trip.status) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              DriverCopy.current.t(
                'This trip is no longer active.',
                "Cette course n'est plus active.",
              ),
            ),
          ),
        );
        return;
      }
      await openActiveTrip(context, trip);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DriverProfile>(
      valueListenable: DriverProfileService.instance.profile,
      builder: (context, profile, _) {
        final rideId = profile.currentRideId;
        if (rideId == null || rideId.isEmpty) return const SizedBox.shrink();
        final l = DriverCopy.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _opening ? null : () => _open(rideId),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const PulsingDot(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('Active Trip in Progress', 'Course active en cours'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.t(
                              'Tap to return to your current trip',
                              'Appuyez pour revenir à votre course en cours',
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_opening)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 12,
    child: Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1).animate(_controller),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
