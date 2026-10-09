import 'dart:async';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/google_maps_launcher.dart';
import '../../../core/utils/waze_launcher.dart';
import '../../../services/navigation_service.dart';
import '../../../theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bottom sheet offering the driver a choice between the app's built-in
/// turn-by-turn screen and handing navigation off to Google Maps or Waze.
Future<void> showNavigateChoiceSheet(
  BuildContext context, {
  required double destinationLat,
  required double destinationLng,
  // Takes the chosen route's index into NavigationService.fetchRouteChoices()'s result (always 0
  // when only one road existed, so the picker step below was skipped entirely).
  required void Function(int routeChoiceIndex) onInAppNavigate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.navigation_rounded, color: AppColors.primary),
            title: Text(
              DriverCopy.current.t('In-app navigation', 'Navigation intégrée'),
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              await _startInAppNavigation(
                context,
                destinationLat: destinationLat,
                destinationLng: destinationLng,
                onInAppNavigate: onInAppNavigate,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.map_outlined, color: AppColors.primary),
            title: Text(
              DriverCopy.current.t('Open in Google Maps', 'Ouvrir dans Google Maps'),
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              final opened = await GoogleMapsLauncher.navigate(
                lat: destinationLat,
                lng: destinationLng,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      DriverCopy.current.t(
                        'Could not open Google Maps. Please try again.',
                        "Impossible d'ouvrir Google Maps. Veuillez réessayer.",
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.map_outlined, color: AppColors.primary),
            title: Text(DriverCopy.current.t('Open in Waze', 'Ouvrir dans Waze')),
            onTap: () async {
              Navigator.pop(sheetContext);
              final opened = await WazeLauncher.navigate(
                lat: destinationLat,
                lng: destinationLng,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      DriverCopy.current.t(
                        'Could not open Waze. Please try again.',
                        "Impossible d'ouvrir Waze. Veuillez réessayer.",
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          SizedBox(height: 8),
        ],
      ),
    ),
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

  // Only one road (or the fetch failed, in which case startNavigationWithChoice's own
  // fallback inside DriverNavigationScreen re-fetches with its usual single-route path) - no
  // real choice to make, so don't make the driver tap through an extra step for nothing.
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
              DriverCopy.current.t('Choose a road', 'Choisissez un itinéraire'),
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
