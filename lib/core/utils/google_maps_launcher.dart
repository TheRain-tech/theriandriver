import 'package:url_launcher/url_launcher.dart';

/// Launches Google Maps turn-by-turn navigation to a destination. Uses the
/// universal `https://www.google.com/maps/dir/...` link rather than a
/// `geo:`/`google.navigation:` scheme - it opens the Google Maps app when
/// installed (true on nearly every Android device) and falls back to the
/// browser when it isn't, so this never requires the app to be present the
/// way Waze's own deep link does.
class GoogleMapsLauncher {
  static Future<bool> navigate({
    required double lat,
    required double lng,
  }) {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
