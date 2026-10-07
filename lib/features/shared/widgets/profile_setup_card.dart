import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

/// The single "your profile/verification needs attention" card, shown in two places:
/// - NotificationsScreen (tap-anywhere row, always visible in the notification feed)
/// - DriverDashboardScreen home (an explicit "Complete Profile" button, directly under the
///   Approval Required status - previously this call-to-action only lived inside
///   Notifications, which a driver blocked from going online had no obvious reason to open, and
///   the home screen's own reminder - formerly `_SetupReminder` - had no explicit button, only a
///   tap-anywhere row).
///
/// Both usages navigate to the same [RouteNames.application] route and read the same
/// [DriverProfile.verificationStatus]; there is deliberately only one copy of this logic (title,
/// message, and the three states below) so the two places can never drift into inconsistent
/// wording or a different destination.
class ProfileSetupCard extends StatelessWidget {
  const ProfileSetupCard({super.key, required this.profile, this.asButton = false});

  final DriverProfile profile;

  /// false (default): notification-style tappable row with a trailing chevron.
  /// true: home-style card with an explicit "Complete Profile" button.
  final bool asButton;

  // lifecycleStatus is the server-owned field node-api's applicationLifecycle.service.js actually
  // keeps current as a driver moves through the pipeline; verificationStatus is the legacy field
  // that only gets written at a few specific points (see driver.service.js) and otherwise goes
  // stale. Checking lifecycleStatus first - the same fix VerificationPendingScreen's _statusLabel
  // already applies - is what stops a driver who has genuinely submitted and been scheduled for
  // an appointment from seeing this card fall through to its "not started yet" default.
  static const _inReviewLifecycleStatuses = {
    'SUBMITTED',
    'PENDING_APPOINTMENT',
    'APPOINTMENT_SCHEDULED',
    'APPOINTMENT_COMPLETED',
    'UNDER_VERIFICATION',
  };

  String? get _lifecycle => profile.lifecycleStatus?.toUpperCase();

  bool get _pending =>
      profile.verificationStatus == DriverVerificationStatus.pending ||
      _inReviewLifecycleStatuses.contains(_lifecycle);

  bool get _needsChanges =>
      profile.verificationStatus == DriverVerificationStatus.rejected ||
      profile.verificationStatus == DriverVerificationStatus.resubmissionRequired ||
      _lifecycle == 'REJECTED';

  bool get _appointmentScheduled => _lifecycle == 'APPOINTMENT_SCHEDULED';

  String _title(DriverCopy l) => _pending
      ? (_appointmentScheduled
          ? l.t('Appointment Required', 'Rendez-vous requis')
          : l.t('Application Submitted', 'Candidature soumise'))
      : _needsChanges
          ? l.t('Application Requires Changes', 'La candidature nécessite des modifications')
          : l.t('Complete your driver profile', 'Complétez votre profil chauffeur');

  String _body(DriverCopy l) => _pending
      ? (_appointmentScheduled
          ? l.t(
              'Please attend your scheduled appointment for final document verification.',
              'Veuillez vous présenter à votre rendez-vous prévu pour la vérification finale des documents.',
            )
          : l.t(
              'Your documents are under review. Please attend your appointment for final verification.',
              'Vos documents sont en cours de vérification. Veuillez vous présenter à votre rendez-vous pour la vérification finale.',
            ))
      : _needsChanges
          ? l.t(
              'Review the feedback and update the requested information before resubmitting.',
              'Consultez les commentaires et mettez à jour les informations demandées avant de soumettre à nouveau.',
            )
          : l.t(
              'Add your required personal, vehicle, fleet and document information to continue your verification.',
              'Ajoutez vos informations personnelles, véhicule, flotte et documents requis pour continuer votre vérification.',
            );

  void _openApplication(BuildContext context) =>
      Navigator.pushNamed(context, RouteNames.application);

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconWell(
          icon: Icons.assignment_outlined,
          color: AppColors.warning,
          background: Colors.white,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(l),
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _body(l),
                style: TextStyle(color: AppColors.textSecondaryFor(context)),
              ),
            ],
          ),
        ),
        if (!asButton)
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondaryFor(context),
          ),
      ],
    );

    if (!asButton) {
      return AppCard(
        color: AppColors.warningSoftFor(context),
        onTap: () => _openApplication(context),
        child: header,
      );
    }

    return AppCard(
      color: AppColors.warningSoftFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (!_pending) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openApplication(context),
                icon: const Icon(Icons.edit_document, size: 18),
                label: Text(
                  _needsChanges
                      ? l.t('Update Application', 'Mettre à jour la candidature')
                      : l.t('Complete Profile', 'Compléter le profil'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
