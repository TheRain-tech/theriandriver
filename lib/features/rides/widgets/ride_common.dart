import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/driver_trip.dart';
import '../../../data/models/live_location.dart';
import '../../../services/location_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/map_preview_card.dart';

class RiderCard extends StatelessWidget {
  const RiderCard({super.key, required this.trip, this.showChat = false});

  final DriverTrip trip;
  final bool showChat;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        const CircleAvatar(
          radius: 31,
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.riderName,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  Text(
                    ' ${trip.riderRating}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: trip.riderPhone.isEmpty
              ? null
              : () => launchUrl(Uri(scheme: 'tel', path: trip.riderPhone)),
          icon: const Icon(Icons.call_rounded),
        ),
        if (showChat) ...[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: trip.riderPhone.isEmpty
                ? null
                : () => launchUrl(Uri(scheme: 'sms', path: trip.riderPhone)),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ],
    ),
  );
}

class RideTrackingMap extends StatefulWidget {
  const RideTrackingMap({
    super.key,
    required this.trip,
    required this.height,
    required this.toPickup,
  });

  final DriverTrip trip;
  final double height;
  final bool toPickup;

  @override
  State<RideTrackingMap> createState() => _RideTrackingMapState();
}

class _RideTrackingMapState extends State<RideTrackingMap> {
  StreamSubscription<LiveLocation?>? _riderSubscription;
  LiveLocation? _riderLocation;

  @override
  void initState() {
    super.initState();
    _listenToRider();
  }

  @override
  void didUpdateWidget(covariant RideTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.trip.riderId != widget.trip.riderId) {
      _listenToRider();
    }
  }

  Future<void> _listenToRider() async {
    await _riderSubscription?.cancel();
    _riderSubscription = null;
    _riderLocation = null;
    if (widget.trip.id.isEmpty || widget.trip.riderId.isEmpty) return;
    _riderSubscription = LocationService.instance
        .watchRiderLocation(
          riderId: widget.trip.riderId,
          rideId: widget.trip.id,
        )
        .listen((location) {
          if (mounted) setState(() => _riderLocation = location);
        });
  }

  @override
  void dispose() {
    _riderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapPreviewCard(
      height: widget.height,
      pickupLat: widget.toPickup ? widget.trip.pickupLat : null,
      pickupLng: widget.toPickup ? widget.trip.pickupLng : null,
      destinationLat: widget.toPickup ? null : widget.trip.dropOffLat,
      destinationLng: widget.toPickup ? null : widget.trip.dropOffLng,
      riderLocation: _riderLocation,
      routePolyline: widget.trip.routePolyline,
    );
  }
}

class RideMetric extends StatelessWidget {
  const RideMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
