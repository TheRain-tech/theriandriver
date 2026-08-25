import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/location_service.dart';
import '../../../services/navigation_service.dart';
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
  });

  final LatLng destination;
  final String destinationLabel;

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  GoogleMapController? _mapController;
  bool _voiceEnabled = true;
  bool _hasCenteredOnce = false;

  @override
  void initState() {
    super.initState();
    NavigationService.instance.startNavigation(
      destination: widget.destination,
      destinationLabel: widget.destinationLabel,
    );
    NavigationService.instance.state.addListener(_onNavigationStateChanged);
    LocationService.instance.currentLocation.addListener(_onLocationChanged);
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
    final controller = _mapController;
    if (location == null || controller == null) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.lat, location.lng),
          zoom: 17.5,
          tilt: 55,
          bearing: location.heading,
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
        title: Text('Stop navigation?'),
        content: Text(
          'You will stop receiving turn-by-turn directions and voice guidance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep navigating'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Stop'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) Navigator.of(context).maybePop(false);
  }

  @override
  Widget build(BuildContext context) {
    final navState = NavigationService.instance.state.value;
    final location = LocationService.instance.currentLocation.value;
    final driverLatLng = location == null
        ? widget.destination
        : LatLng(location.lat, location.lng);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driverLatLng,
              zoom: 16,
            ),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('driver'),
                position: driverLatLng,
                rotation: location?.heading ?? 0,
                anchor: const Offset(0.5, 0.5),
                flat: true,
                icon: BitmapDescriptor.defaultMarkerWithHue(
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
                    CameraPosition(target: driverLatLng, zoom: 17, tilt: 55),
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
