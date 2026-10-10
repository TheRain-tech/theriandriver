import '../../../core/localization/driver_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/driver_trip.dart';
import '../../../data/models/live_location.dart';
import '../../../services/chat_unread_count_service.dart';
import '../../../services/location_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/map_preview_card.dart';
import '../screens/ride_chat_screen.dart';

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
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return AppCard(
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
            message: l.t('Call rider', 'Appeler le passager'),
            child: IconButton.filledTonal(
              onPressed: trip.riderPhone.isEmpty
                  ? null
                  : () => _launchRiderCall(context, phone: trip.riderPhone),
              icon: Icon(Icons.call_rounded),
            ),
          ),
          if (showChat) ...[
            SizedBox(width: 6),
            Tooltip(
              message: l.t('Message rider', 'Envoyer un message au passager'),
              child: StreamBuilder<int>(
                stream: watchRideChatUnreadCount(trip.id),
                builder: (context, unreadSnapshot) => IconButton.filledTonal(
                  // Real in-app, real-time chat (see RideChatScreen) rather than handing off to
                  // the device's own SMS app - the ride-scoped, persisted chat the rest of the
                  // app uses.
                  onPressed: trip.id.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RideChatScreen(rideId: trip.id),
                          ),
                        ),
                  icon: Badge.count(
                    count: unreadSnapshot.data ?? 0,
                    isLabelVisible: (unreadSnapshot.data ?? 0) > 0,
                    child: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    ),
  );
  }
}

Future<void> _launchRiderCall(BuildContext context, {required String phone}) async {
  try {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: phone.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          DriverCopy.current.t(
            'No calling app is available on this device.',
            "Aucune application d'appel n'est disponible sur cet appareil.",
          ),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          DriverCopy.current.t(
            'Could not open rider contact. Please try again.',
            "Impossible d'ouvrir le contact du passager. Veuillez réessayer.",
          ),
        ),
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
      driverRideType: widget.trip.rideType,
      // routePolyline is the rider's pickup-to-destination route - only the destination leg
      // (toPickup: false, trip_in_progress_screen) is actually driving along it; snapping during
      // the go-to-pickup leg would show a fake position on a line the driver isn't on yet.
      snapToRoute: !widget.toPickup,
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
