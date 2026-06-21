import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/env_config.dart';
import '../../../data/models/live_location.dart';
import '../../../services/location_service.dart';
import '../../../theme/app_colors.dart';

class MapPreviewCard extends StatefulWidget {
  const MapPreviewCard({
    super.key,
    this.height = 220,
    this.showCar = true,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.riderLocation,
    this.routePolyline = '',
  });

  final double height;
  final bool showCar;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final LiveLocation? riderLocation;
  final String routePolyline;

  @override
  State<MapPreviewCard> createState() => _MapPreviewCardState();
}

class _MapPreviewCardState extends State<MapPreviewCard> {
  GoogleMapController? _mapController;
  LatLng? _lastCameraLocation;

  bool get _canUseGoogleMap =>
      EnvConfig.googleMapsApiKey.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _canUseGoogleMap
            ? ValueListenableBuilder<LiveLocation?>(
                valueListenable: LocationService.instance.currentLocation,
                builder: (context, driverLocation, _) =>
                    _buildGoogleMap(driverLocation),
              )
            : _MapFallback(showCar: widget.showCar),
      ),
    );
  }

  Widget _buildGoogleMap(LiveLocation? driverLocation) {
    final driver = driverLocation == null
        ? null
        : LatLng(driverLocation.lat, driverLocation.lng);
    final pickup = _coordinate(widget.pickupLat, widget.pickupLng);
    final destination = _coordinate(
      widget.destinationLat,
      widget.destinationLng,
    );
    final rider = widget.riderLocation == null
        ? null
        : LatLng(widget.riderLocation!.lat, widget.riderLocation!.lng);
    final initial =
        driver ?? pickup ?? destination ?? const LatLng(5.9631, 10.1591);

    if (driver != null && driver != _lastCameraLocation) {
      _lastCameraLocation = driver;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController?.animateCamera(CameraUpdate.newLatLng(driver));
        } catch (e) {
          debugPrint('GoogleMap animateCamera failed: $e');
        }
      });
    }

    final markers = <Marker>{
      if (widget.showCar && driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          infoWindow: const InfoWindow(title: 'Your live location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      if (destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      if (rider != null)
        Marker(
          markerId: const MarkerId('rider'),
          position: rider,
          infoWindow: const InfoWindow(title: 'Rider live location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
        ),
    };

    final routePoints = _routePoints(
      driver: driver,
      pickup: pickup,
      destination: destination,
    );
    final polylines = routePoints.length < 2
        ? <Polyline>{}
        : {
            Polyline(
              polylineId: const PolylineId('active-route'),
              points: routePoints,
              color: AppColors.primary,
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initial, zoom: 14.5),
      markers: markers,
      polylines: polylines,
      compassEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) => _mapController = controller,
    );
  }

  List<LatLng> _routePoints({
    required LatLng? driver,
    required LatLng? pickup,
    required LatLng? destination,
  }) {
    if (widget.routePolyline.trim().isNotEmpty) {
      try {
        return PolylinePoints.decodePolyline(widget.routePolyline)
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false);
      } catch (_) {
        // Fall back to a direct line if the backend polyline is malformed.
      }
    }
    return [driver, pickup, destination].whereType<LatLng>().toList();
  }

  LatLng? _coordinate(double? lat, double? lng) {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.showCar});

  final bool showCar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _MapPainter(showCar: showCar)),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Map is unavailable. Check the Maps API key and location '
                'permission.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.slate),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.showCar});

  final bool showCar;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF2F6FA),
    );
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final thinRoad = Paint()
      ..color = const Color(0xFFDDE6F0)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = -2; i < 9; i++) {
      final y = size.height * (i / 7);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 65), road);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 65), thinRoad);
    }
    for (var i = -1; i < 8; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(Offset(x, 0), Offset(x + 55, size.height), road);
      canvas.drawLine(Offset(x, 0), Offset(x + 55, size.height), thinRoad);
    }
    final route = Path()
      ..moveTo(size.width * .14, size.height * .76)
      ..lineTo(size.width * .31, size.height * .58)
      ..lineTo(size.width * .49, size.height * .63)
      ..lineTo(size.width * .65, size.height * .36)
      ..lineTo(size.width * .84, size.height * .24);
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(size.width * .14, size.height * .76),
      12,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      Offset(size.width * .84, size.height * .24),
      12,
      Paint()..color = AppColors.success,
    );
    if (showCar) {
      final carOffset = Offset(size.width * .5, size.height * .59);
      canvas.drawCircle(carOffset, 16, Paint()..color = Colors.white);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: carOffset, width: 23, height: 13),
          const Radius.circular(5),
        ),
        Paint()..color = AppColors.navy,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      showCar != oldDelegate.showCar;
}
