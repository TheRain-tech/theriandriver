import 'package:flutter/widgets.dart';

/// The shared, high-frequency driver UI copy. It keeps the app's selected
/// locale useful before the remaining feature screens move to generated ARB
/// localization.
class DriverCopy {
  const DriverCopy._(this.isFrench);

  final bool isFrench;

  static DriverCopy of(BuildContext context) => DriverCopy._(
    Localizations.localeOf(context).languageCode.toLowerCase() == 'fr',
  );

  String get home => isFrench ? 'Accueil' : 'Home';
  String get earnings => isFrench ? 'Revenus' : 'Earnings';
  String get trips => isFrench ? 'Courses' : 'Trips';
  String get wallet => isFrench ? 'Portefeuille' : 'Wallet';
  String get profile => isFrench ? 'Profil' : 'Profile';
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
