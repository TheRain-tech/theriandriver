import 'package:url_launcher/url_launcher.dart';

/// Launches Waze turn-by-turn navigation to a destination. Tries the native
/// `waze://` scheme first (works whether or not Waze is installed on iOS,
/// per Waze's documented deep link behavior) and falls back to the web
/// universal link if that fails to launch.
class WazeLauncher {
  static Future<bool> navigate({
    required double lat,
    required double lng,
  }) async {
    final appUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    if (await canLaunchUrl(appUri)) {
      final opened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    }
    final webUri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
