import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/driver_ride_api_client.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';

/// Adapts node-api's ride JSON (pickup/destination/pricing objects - see
/// ride.service.js#requestRide) into the same [DriverTrip] shape
/// GoToPickupScreen/PickupConfirmedScreen already render, so a ride created
/// via node-api's own booking path (including a scheduled ride's 8-minutes-
/// before activation) drops straight into the existing, working post-accept
/// trip screens instead of needing new ones. Rider name/rating aren't part
/// of node-api's ride record yet, so those fall back to DriverTrip's own
/// defaults, same as this screen's existing pickup/destination/fare rows.
DriverTrip _driverTripFromNodeApiRide(Map<String, dynamic> ride, String driverId) {
  final pickup = ride['pickup'] is Map ? (ride['pickup'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
  final destination = ride['destination'] is Map ? (ride['destination'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
  final pricing = ride['pricing'] is Map ? (ride['pricing'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
  final fare = double.tryParse((pricing['estimatedFareXaf'] ?? pricing['estimatedFare'] ?? pricing['total'])?.toString() ?? '') ?? 0;
  final scheduledPickupAt = ride['scheduledPickupAt'] is String ? DateTime.tryParse(ride['scheduledPickupAt'] as String)?.toLocal() : null;
  return DriverTrip(
    id: ride['id']?.toString() ?? '',
    driverId: driverId,
    riderName: 'Rider',
    riderRating: 0,
    pickup: pickup['address']?.toString() ?? '',
    dropOff: destination['address']?.toString() ?? '',
    fare: fare,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: TripStatus.accepted,
    rideType: ride['rideType']?.toString() ?? 'classic',
    distanceKm: 0,
    durationMinutes: 0,
    createdAt: DateTime.now(),
    riderId: ride['riderId']?.toString() ?? '',
    riderPhone: ride['riderPhone']?.toString() ?? '',
    pickupLat: double.tryParse(pickup['lat']?.toString() ?? '') ?? 0,
    pickupLng: double.tryParse(pickup['lng']?.toString() ?? '') ?? 0,
    dropOffLat: double.tryParse(destination['lat']?.toString() ?? '') ?? 0,
    dropOffLng: double.tryParse(destination['lng']?.toString() ?? '') ?? 0,
    scheduledPickupAt: scheduledPickupAt,
  );
}

/// Counterpart to NewRideRequestScreen for a ride that was created directly
/// through node-api (POST /rides), not theriandriver's usual Firestore-bridge
/// flow - reached only via NotificationService's RIDE_REQUEST push handler,
/// itself only active when EnvConfig.useNodeApiRideAcceptance is on. Uses
/// DriverRideApiClient (accept/decline call node-api directly) rather than
/// RideRepository's Firestore transactions, since this ride doesn't exist in
/// the ride_requests collection that flow watches.
class NodeApiRideOfferScreen extends StatefulWidget {
  const NodeApiRideOfferScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<NodeApiRideOfferScreen> createState() => _NodeApiRideOfferScreenState();
}

class _NodeApiRideOfferScreenState extends State<NodeApiRideOfferScreen> {
  Map<String, dynamic>? _ride;
  String? _loadError;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ride = await DriverRideApiClient.instance.getRide(widget.rideId);
      if (!mounted) return;
      setState(() => _ride = ride);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'This ride offer is no longer available.');
    }
  }

  Future<void> _accept() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    try {
      final accepted = await DriverRideApiClient.instance.acceptRide(widget.rideId);
      final profile = DriverProfileService.instance.profile.value;
      TripService.instance.activeTrip.value = _driverTripFromNodeApiRide(accepted, profile.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(RouteNames.goToPickup);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _decline() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    try {
      await DriverRideApiClient.instance.declineRide(widget.rideId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      _showMessage(_friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('RIDE_UNAVAILABLE') || message.contains('no longer available')) {
      return 'This ride was already taken by another driver.';
    }
    if (message.contains('RIDE_NOT_OFFERED')) {
      return 'This ride was not offered to you.';
    }
    return 'Could not respond to this ride. Please try again.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    return Scaffold(
      appBar: const DriverAppBar(title: 'Ride Offer', showBack: true, showLogo: false),
      body: SafeArea(
        top: false,
        child: _loadError != null
            ? Center(child: Text(_loadError!))
            : ride == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('Pickup', _addressOf(ride['pickup'])),
                          const Divider(height: 24),
                          _row('Destination', _addressOf(ride['destination'])),
                          const Divider(height: 24),
                          _row('Ride type', (ride['rideType'] ?? '-').toString()),
                          const Divider(height: 24),
                          _row('Fare', _fareOf(ride['pricing'])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isResponding ? null : _decline,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding: const EdgeInsets.symmetric(vertical: 17),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isResponding ? null : _accept,
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 17)),
                            child: _isResponding
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate)),
        Flexible(
          child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  String _addressOf(Object? point) {
    if (point is! Map) return '-';
    final address = point['address'];
    if (address is String && address.isNotEmpty) return address;
    final lat = point['lat'];
    final lng = point['lng'];
    if (lat != null && lng != null) return '$lat, $lng';
    return '-';
  }

  String _fareOf(Object? pricing) {
    if (pricing is! Map) return '-';
    final total = pricing['total'] ?? pricing['estimatedFareXaf'] ?? pricing['fare'];
    final amount = double.tryParse(total?.toString() ?? '');
    if (amount == null) return '-';
    return CurrencyFormatter.format(amount);
  }
}
