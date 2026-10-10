import 'dart:async';

import '../../../core/localization/driver_copy.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../services/navigation_service.dart';
import '../../../theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Starts the driver's required in-app turn-by-turn navigation path.
///
/// The driver app no longer offers Google Maps or Waze handoff from the ride
/// flow. A successful start records the same navigation-started signal used by
/// node-api so the rider is still notified that the driver is on the way.
Future<void> showNavigateChoiceSheet(
  BuildContext context, {
  required String rideId,
  required double destinationLat,
  required double destinationLng,
  required void Function(int routeChoiceIndex) onInAppNavigate,
}) async {
  final repository = RideRepository();
  unawaited(
    repository.recordNavigationStarted(rideId: rideId, provider: 'in_app'),
  );
  await _startInAppNavigation(
    context,
    destinationLat: destinationLat,
    destinationLng: destinationLng,
    onInAppNavigate: onInAppNavigate,
  );
}

Future<void> _startInAppNavigation(
  BuildContext context, {
  required double destinationLat,
  required double destinationLng,
  required void Function(int routeChoiceIndex) onInAppNavigate,
}) async {
  final destination = LatLng(destinationLat, destinationLng);
  unawaited(_showLoadingDialog(context));
  final choices = await NavigationService.instance.fetchRouteChoices(
    destination,
  );
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (!context.mounted) return;

  if (choices.length < 2) {
    onInAppNavigate(0);
    return;
  }

  final picked = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              DriverCopy.current.t('Choose a road', 'Choisissez un itineraire'),
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (var i = 0; i < choices.length; i++)
            ListTile(
              leading: Icon(
                Icons.alt_route_rounded,
                color: i == 0 ? AppColors.primary : null,
              ),
              title: Text(_formatDuration(choices[i].durationSeconds)),
              subtitle: Text(_formatDistance(choices[i].distanceMeters)),
              trailing: i == 0
                  ? Chip(
                      label: Text(
                        DriverCopy.current.t('Fastest', 'Le plus rapide'),
                      ),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
              onTap: () => Navigator.pop(sheetContext, i),
            ),
          SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked == null) return;
  onInAppNavigate(picked);
}

Future<void> _showLoadingDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
}

String _formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '${hours}h' : '${hours}h${remaining}m';
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
