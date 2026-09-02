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
  const RiderCard({
    super.key,
    required this.trip,
    this.showContact = false,
    this.showChat = true,
  });

  final DriverTrip trip;
  final bool showContact;
  final bool showChat;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        CircleAvatar(
          radius: 31,
          backgroundColor: AppColors.primarySoftFor(context),
          child: Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.riderName,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                  Text(
                    ' ${trip.riderRating}',
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showContact) ...[
          SizedBox(width: 6),
          Tooltip(
            message: 'Call rider',
            child: IconButton.filledTonal(
              onPressed: trip.riderPhone.isEmpty
                  ? null
                  : () => _launchRiderContact(
                      context,
                      scheme: 'tel',
                      phone: trip.riderPhone,
                    ),
              icon: Icon(Icons.call_rounded),
            ),
          ),
          if (showChat) ...[
            SizedBox(width: 6),
            Tooltip(
              message: 'Message rider',
              child: IconButton.filledTonal(
                onPressed: trip.riderPhone.isEmpty
                    ? null
                    : () => _launchRiderContact(
                        context,
                        scheme: 'sms',
                        phone: trip.riderPhone,
                      ),
                icon: Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
          ],
        ],
      ],
    ),
  );
}

Future<void> _launchRiderContact(
  BuildContext context, {
  required String scheme,
  required String phone,
}) async {
  try {
    final opened = await launchUrl(
      Uri(scheme: scheme, path: phone.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheme == 'tel'
              ? 'No calling app is available on this device.'
              : 'No messaging app is available on this device.',
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open rider contact. Please try again.'),
      ),
    );
  }
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
        SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 11,
          ),
        ),
        SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
