import 'package:url_launcher/url_launcher.dart';

/// Same canonical URLs as therian (Rider)'s core/utils/legal_links.dart -
/// one set of legal pages shared across every TheRain app.
class LegalLinks {
  static const String termsUrl = 'https://therain.cm/terms';
  static const String privacyUrl = 'https://therain.cm/privacy';

  static Future<void> openTerms() => _launch(termsUrl);

  static Future<void> openPrivacy() => _launch(privacyUrl);

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
