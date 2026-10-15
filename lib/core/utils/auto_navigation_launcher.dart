import 'package:url_launcher/url_launcher.dart';

import 'google_maps_launcher.dart';

/// Automatically opens external turn-by-turn navigation the moment a driver accepts a ride -
/// Waze first (the driver's usual choice), falling back to Google Maps only when Waze's own
/// native scheme genuinely can't launch (not installed, or blocked by Android 11+ package
/// visibility rules without the `<queries>` entry - see AndroidManifest.xml). Deliberately does
/// NOT fall through to Waze's own web redirect the way WazeLauncher.navigate() does elsewhere in
/// this app - a driver with no Waze app should land straight in Google Maps, not a browser tab.
class AutoNavigationLauncher {
  static Future<void> launchForPickup({
    required double lat,
    required double lng,
  }) async {
    final wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    if (await canLaunchUrl(wazeUri)) {
      final opened = await launchUrl(
        wazeUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    }
    await GoogleMapsLauncher.navigate(lat: lat, lng: lng);
  }
}
