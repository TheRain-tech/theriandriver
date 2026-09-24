import '../../../core/constants/driver_map_style.dart';
import '../../../core/localization/driver_copy.dart';
import '../../../data/models/live_location.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/location_service.dart';
import '../../../services/navigation_service.dart';
import '../../../services/vehicle_marker_factory.dart';
import '../../../theme/app_colors.dart';

/// Full-screen, real turn-by-turn voice navigation to [destination] - shown
/// after accepting a ride (guide to pickup) and again after starting the
/// trip (guide to dropoff). Owns nothing about the ride itself; it only
/// drives [NavigationService] and gets out of the way once the driver
/// arrives or backs out manually, leaving whatever comes next (confirm
/// arrival, start trip, complete trip) to the screen that pushed this one.
class DriverNavigationScreen extends StatefulWidget {
  const DriverNavigationScreen({
    super.key,
    required this.destination,
    required this.destinationLabel,
    required this.driverRideType,
  });

  final LatLng destination;
  final String destinationLabel;
  final String driverRideType;

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  GoogleMapController? _mapController;
  bool _voiceEnabled = true;
  bool _hasCenteredOnce = false;
  LiveLocation? _driverLocation;
  BitmapDescriptor? _vehicleMarker;
  String? _vehicleMarkerRequested;

  @override
  void initState() {
    super.initState();
    NavigationService.instance.startNavigation(
      destination: widget.destination,
      destinationLabel: widget.destinationLabel,
    );
    _driverLocation = LocationService.instance.currentLocation.value;
    NavigationService.instance.state.addListener(_onNavigationStateChanged);
    LocationService.instance.currentLocation.addListener(_onLocationChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadVehicleMarker();
  }

  @override
  void dispose() {
    NavigationService.instance.state.removeListener(_onNavigationStateChanged);
    LocationService.instance.currentLocation.removeListener(_onLocationChanged);
    NavigationService.instance.stopNavigation();
    super.dispose();
  }

  void _onNavigationStateChanged() {
    if (!mounted) return;
    if (NavigationService.instance.state.value == null &&
        !NavigationService.instance.isActive) {
      // The service stopped itself - the driver arrived. Hand control back
      // to whichever screen pushed this one (accept-offer, or trip-in-
      // progress) rather than deciding here what happens after arrival.
      Navigator.of(context).maybePop(true);
      return;
    }
    setState(() {});
  }

  void _onLocationChanged() {
    final location = LocationService.instance.currentLocation.value;
    if (mounted) setState(() => _driverLocation = location);
    final controller = _mapController;
    final point = _locationPoint(location);
    if (point == null || controller == null) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: 17.5,
          tilt: 55,
          bearing: _headingFor(location),
        ),
      ),
    );
    _hasCenteredOnce = true;
  }

  void _toggleVoice() {
    setState(() => _voiceEnabled = !_voiceEnabled);
    NavigationService.instance.setVoiceEnabled(_voiceEnabled);
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DriverCopy.current.t('Stop navigation?', 'Arrêter la navigation ?'),
        ),
        content: Text(
          DriverCopy.current.t(
            'You will stop receiving turn-by-turn directions and voice guidance.',
            'Vous ne recevrez plus les indications de navigation ni le guidage vocal.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              DriverCopy.current.t(
                'Keep navigating',
                'Continuer la navigation',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(DriverCopy.current.t('Stop', 'Arrêter')),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) Navigator.of(context).maybePop(false);
  }

  @override
  Widget build(BuildContext context) {
    final navState = NavigationService.instance.state.value;
    final location = _driverLocation;
    final driverLatLng = _locationPoint(location);
    final initialTarget = driverLatLng ?? widget.destination;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 16,
            ),
            style: DriverMapStyle.light,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              if (driverLatLng != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driverLatLng,
                  rotation: _headingFor(location),
                  anchor: const Offset(.5, .5),
                  flat: _vehicleMarker != null,
                  zIndexInt: 1,
                  icon:
                      _vehicleMarker ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                ),
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
            polylines: {
              if (navState != null && navState.routePolyline.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('nav-route'),
                  points: navState.routePolyline,
                  color: AppColors.primary,
                  width: 6,
                ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_hasCenteredOnce) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: initialTarget, zoom: 17, tilt: 55),
                  ),
                );
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _InstructionBanner(
                  navState: navState,
                  destinationLabel: widget.destinationLabel,
                  onExit: _confirmExit,
                ),
                const Spacer(),
                _BottomBar(
                  navState: navState,
                  voiceEnabled: _voiceEnabled,
                  onToggleVoice: _toggleVoice,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVehicleMarker() async {
    final rideType = widget.driverRideType.trim();
    if (rideType.isEmpty || _vehicleMarkerRequested == rideType) return;
    _vehicleMarkerRequested = rideType;
    try {
      final marker = await VehicleMarkerFactory.forRideOrVehicleType(
        rideType,
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      if (!mounted || _vehicleMarkerRequested != rideType) return;
      setState(() => _vehicleMarker = marker);
    } catch (_) {
      // Navigation must remain available when an optional image cannot load.
    }
  }

  LatLng? _locationPoint(LiveLocation? location) {
    if (location == null ||
        location.lat < -90 ||
        location.lat > 90 ||
        location.lng < -180 ||
        location.lng > 180 ||
        (location.lat == 0 && location.lng == 0)) {
      return null;
    }
    return LatLng(location.lat, location.lng);
  }

  double _headingFor(LiveLocation? location) {
    final heading = location?.heading;
    return heading != null && heading.isFinite && heading >= 0 && heading < 360
        ? heading
        : 0;
  }
}

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.navState,
    required this.destinationLabel,
    required this.onExit,
  });

  final DriverNavigationState? navState;
  final String destinationLabel;
  final VoidCallback onExit;

  IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'TURN_LEFT':
      case 'TURN_SHARP_LEFT':
      case 'TURN_SLIGHT_LEFT':
        return Icons.turn_left_rounded;
      case 'TURN_RIGHT':
      case 'TURN_SHARP_RIGHT':
      case 'TURN_SLIGHT_RIGHT':
        return Icons.turn_right_rounded;
      case 'UTURN_LEFT':
      case 'UTURN_RIGHT':
        return Icons.u_turn_left_rounded;
      case 'ROUNDABOUT_LEFT':
      case 'ROUNDABOUT_RIGHT':
        return Icons.roundabout_left_rounded;
      case 'MERGE':
        return Icons.merge_rounded;
      case 'FORK_LEFT':
      case 'FORK_RIGHT':
        return Icons.fork_right_rounded;
      case 'STRAIGHT':
      default:
        return Icons.straight_rounded;
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final step = navState?.currentStep;
    final isRerouting = navState?.isRerouting ?? false;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primaryDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                _maneuverIcon(step?.maneuver),
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRerouting
                          ? 'Recalculating route...'
                          : navState == null
                          ? 'Loading directions...'
                          : _formatDistance(navState!.distanceToManeuverMeters),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      step?.instruction.isNotEmpty == true
                          ? step!.instruction
                          : 'Head to $destinationLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onExit,
                icon: Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.navState,
    required this.voiceEnabled,
    required this.onToggleVoice,
  });

  final DriverNavigationState? navState;
  final bool voiceEnabled;
  final VoidCallback onToggleVoice;

  String _formatEta(int seconds) {
    if (seconds < 60) return '<1 min';
    final minutes = (seconds / 60).round();
    return '$minutes min';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      navState == null
                          ? '--'
                          : _formatEta(navState!.remainingSeconds),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      navState == null
                          ? 'To destination'
                          : '${_formatDistance(navState!.remainingDistanceMeters)} remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onToggleVoice,
                icon: Icon(
                  voiceEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
                tooltip: voiceEnabled
                    ? 'Mute voice guidance'
                    : 'Unmute voice guidance',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
