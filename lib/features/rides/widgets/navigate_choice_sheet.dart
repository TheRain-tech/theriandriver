import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/waze_launcher.dart';
import '../../../theme/app_colors.dart';

import 'package:flutter/material.dart';

/// Bottom sheet offering the driver a choice between the app's built-in
/// turn-by-turn screen and handing navigation off to Waze.
Future<void> showNavigateChoiceSheet(
  BuildContext context, {
  required double destinationLat,
  required double destinationLng,
  required VoidCallback onInAppNavigate,
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
            onTap: () {
              Navigator.pop(sheetContext);
              onInAppNavigate();
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
