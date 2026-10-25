import 'package:flutter/widgets.dart';

import '../../services/driver_preferences_service.dart';

/// The shared, high-frequency driver UI copy. It keeps the app's selected
/// locale useful before the remaining feature screens move to generated ARB
/// localization.
class DriverCopy {
  const DriverCopy._(this.isFrench);

  final bool isFrench;

  static DriverCopy of(BuildContext context) => DriverCopy._(
    Localizations.localeOf(context).languageCode.toLowerCase() == 'fr',
  );

  /// The driver's current language without needing a BuildContext - snackbars and dialogs are
  /// often shown after an await, where the context should not be used.
  static DriverCopy get current => DriverCopy._(
    DriverPreferencesService.instance.preferences.value.locale.languageCode
            .toLowerCase() ==
        'fr',
  );

  /// One message in both languages, chosen by the driver's language.
  String t(String en, String fr) => isFrench ? fr : en;

  String get home => isFrench ? 'Accueil' : 'Home';
  String get earnings => isFrench ? 'Revenus' : 'Earnings';
  String get trips => isFrench ? 'Courses' : 'Trips';
  String get trip => isFrench ? 'Course' : 'Trip';
  String get wallet => isFrench ? 'Portefeuille' : 'Wallet';
  String get map => isFrench ? 'Carte' : 'Map';
  String get chat => isFrench ? 'Discussion' : 'Chat';
  String get fleetChatUnavailable => isFrench
      ? 'La conversation de flotte est disponible après l’approbation et l’activation de votre adhésion.'
      : 'Fleet chat is available after your membership is approved and active.';
  String get startFleetConversation =>
      isFrench ? 'Démarrez la conversation' : 'Start the conversation';
  String get messageFleetOwner => isFrench
      ? 'Écrivez au responsable de votre flotte'
      : 'Message your fleet owner';
  String get refreshMessages =>
      isFrench ? 'Actualiser les messages' : 'Refresh messages';
  String get send => isFrench ? 'Envoyer' : 'Send';
  String get retry => isFrench ? 'Réessayer' : 'Retry';
  String get tryAgain => isFrench ? 'Réessayer' : 'Try again';
  String get profile => isFrench ? 'Profil' : 'Profile';
  String get noActiveTripChatTitle =>
      isFrench ? 'Aucune discussion active' : 'No active trip chat';
  String get noActiveTripChatMessage => isFrench
      ? 'Vous pourrez discuter avec votre passager dès que vous aurez une course active.'
      : "You'll be able to chat with your rider once you have an active trip.";
  String get openChatWithRider =>
      isFrench ? 'Ouvrir la discussion' : 'Open chat';
  String get settings => isFrench ? 'Paramètres' : 'Settings';
  String get account => isFrench ? 'Compte' : 'Account';
  String get preferences => isFrench ? 'Préférences' : 'Preferences';
  String get support => isFrench ? 'Assistance' : 'Support';
  String get language => isFrench ? 'Langue' : 'Language';
  String get appTheme => isFrench ? "Thème de l'application" : 'App Theme';
  String get rideAlerts => isFrench ? 'Alertes de course' : 'Ride alerts';
  String get light => isFrench ? 'Clair' : 'Light';
  String get dark => isFrench ? 'Sombre' : 'Dark';
  String get systemDefault => isFrench ? 'Système' : 'System default';
  String get english => 'English';
  String get french => 'Français';
  String get chooseLanguage =>
      isFrench ? 'Choisir la langue' : 'Choose language';
  String get chooseTheme => isFrench ? 'Choisir le thème' : 'Choose theme';
  String get personalInformation =>
      isFrench ? 'Informations personnelles' : 'Personal Information';
  String get changePassword =>
      isFrench ? 'Changer le mot de passe' : 'Change Password';
  String get privacyPolicy =>
      isFrench ? 'Politique de confidentialité' : 'Privacy Policy';
  String get termsOfService =>
      isFrench ? "Conditions d'utilisation" : 'Terms of Service';
  String get helpCenter => isFrench ? "Centre d'aide" : 'Help Center';
  String get aboutDriver =>
      isFrench ? 'À propos de TheRain Driver' : 'About TheRain Driver';
  String get logout => isFrench ? 'Déconnexion' : 'Logout';
  String get goodMorning => isFrench ? 'Bonjour,' : 'Good Morning,';
  String get driverDashboard =>
      isFrench ? 'Tableau de bord chauffeur' : 'Driver dashboard';
  String get notifications => isFrench ? 'Notifications' : 'Notifications';
  String get online => isFrench ? 'En ligne' : 'Online';
  String get offline => isFrench ? 'Hors ligne' : 'Offline';
  String get newRideRequest =>
      isFrench ? 'Nouvelle demande de course' : 'New ride request';
  String get openIncomingRide =>
      isFrench ? 'Voir la course entrante' : 'Open Incoming Ride';
  String get todayEarnings =>
      isFrench ? "Revenus d'aujourd’hui" : "Today's Earnings";
  String get viewEarnings => isFrench ? 'Voir les revenus' : 'View earnings';
}
