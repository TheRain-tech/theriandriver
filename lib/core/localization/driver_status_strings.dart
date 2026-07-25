import 'package:flutter/widgets.dart';

class DriverStatusStrings {
  const DriverStatusStrings._(this.isFrench);

  final bool isFrench;

  static DriverStatusStrings of(BuildContext context) => DriverStatusStrings._(
        Localizations.localeOf(context).languageCode.toLowerCase() == 'fr',
      );

  String get comingSoonTitle => isFrench
      ? 'TheRain arrive bientôt dans votre région'
      : 'TheRain is Coming Soon to Your Region';
  String get comingSoonIntro => isFrench
      ? 'Merci de vous être inscrit auprès de TheRain.\n\nNous avons bien reçu votre candidature.'
      : 'Thank you for registering with TheRain.\n\nWe have successfully received your application.';
  String get comingSoonDetails => isFrench
      ? "TheRain n'a pas encore officiellement lancé ses opérations dans la région sélectionnée.\n\n"
          "Votre candidature a été enregistrée en toute sécurité et passera automatiquement à l'étape d'examen dès le lancement des opérations dans votre région.\n\n"
          "Nous vous informerons par e-mail et dans l'application lorsque TheRain sera disponible."
      : 'TheRain has not yet officially launched operations in your selected region.\n\n'
          'Your application has been securely saved and will automatically move into the review process as soon as operations begin in your region.\n\n'
          'We will notify you by email and inside the app when TheRain becomes available.';
  String get viewApplicationStatus =>
      isFrench ? 'Voir le statut de la candidature' : 'View Application Status';
  String get contactSupport =>
      isFrench ? "Contacter l'assistance" : 'Contact Support';
  String get stillWaiting => isFrench
      ? 'Votre candidature est enregistrée et attend le lancement régional.'
      : 'Your application is securely saved and waiting for regional launch.';
  String get accountSuspendedTitle =>
      isFrench ? 'Compte suspendu' : 'Account Suspended';
  String get fleetSuspendedTitle => isFrench
      ? 'Flotte temporairement suspendue'
      : 'Fleet Temporarily Suspended';
  String get accountSuspendedMessage => isFrench
      ? "Votre compte TheRain a été temporairement suspendu.\n\nPendant cette période, vous ne pouvez pas accéder aux opérations de transport ni aux autres services restreints."
      : 'Your TheRain account has been temporarily suspended.\n\nDuring this period you cannot access ride operations or other restricted services.';
  String get accountSuspendedGuidance => isFrench
      ? "Consultez les informations de suspension ci-dessous ou contactez l'assistance TheRain si vous pensez que cette décision est une erreur."
      : 'Please review the suspension information below or contact TheRain Support if you believe this decision was made in error.';
  String get accountSuspendedFooter => isFrench
      ? "Votre compte restera suspendu jusqu'à la fin de l'examen par TheRain ou jusqu'à la résolution des conditions de suspension."
      : 'Your account will remain suspended until TheRain completes the review or the suspension conditions are resolved.';
  String get fleetSuspendedMessage => isFrench
      ? "Le compte de votre propriétaire de flotte a été temporairement suspendu par TheRain.\n\nLes demandes de course sont temporairement indisponibles.\n\nContactez votre propriétaire de flotte ou l'assistance TheRain."
      : 'Your Fleet Owner account has been temporarily suspended by TheRain.\n\nRide requests are temporarily unavailable.\n\nPlease contact your Fleet Owner or TheRain Support for assistance.';
  String get status => isFrench ? 'Statut' : 'Status';
  String get suspended => isFrench ? 'Suspendu' : 'Suspended';
  String get suspensionId => isFrench ? 'ID de suspension' : 'Suspension ID';
  String get suspensionDate =>
      isFrench ? 'Date de suspension' : 'Suspension Date';
  String get suspensionReason =>
      isFrench ? 'Motif de suspension' : 'Suspension Reason';
  String get reviewStatus => isFrench ? "Statut de l'examen" : 'Review Status';
  String get contactFleetManager => isFrench
      ? 'Contacter le gestionnaire de flotte'
      : 'Contact Fleet Manager';
  String get contactTheRainSupport =>
      isFrench ? "Contacter l'assistance TheRain" : 'Contact TheRain Support';
  String get viewSuspensionDetails => isFrench
      ? 'Voir les détails de la suspension'
      : 'View Suspension Details';
  String get suspensionDetailsTitle =>
      isFrench ? 'Détails de la suspension' : 'Suspension Details';
  String get restoredAutomatically => isFrench
      ? 'Cette restriction disparaîtra automatiquement lorsque TheRain rétablira votre flotte.'
      : 'This restriction will disappear automatically when TheRain restores your fleet.';
}
