import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/repositories/driver_verification_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';

class VerificationReviewSubmitScreen extends StatefulWidget {
  const VerificationReviewSubmitScreen({super.key});

  @override
  State<VerificationReviewSubmitScreen> createState() =>
      _VerificationReviewSubmitScreenState();
}

class _VerificationReviewSubmitScreenState
    extends State<VerificationReviewSubmitScreen> {
  bool _isSubmitting = false;
  final _driverRepository = DriverRepository();
  final _verificationRepository = DriverVerificationRepository();

  @override
  void initState() {
    super.initState();
    _loadSavedDraft();
  }

  Future<void> _loadSavedDraft() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    try {
      final profile = await _driverRepository.getProfile(uid);
      final verification = await _verificationRepository.getVerification(uid);
      final payout = await _driverRepository.getDefaultPayoutAccount(uid);
      if (!mounted) return;
      final current = RegistrationDraftService.instance.value;
      RegistrationDraftService.instance.draft.value = current.copyWith(
        fullName: current.fullName.isNotEmpty
            ? current.fullName
            : profile?.fullName,
        phoneNumber: current.phoneNumber.isNotEmpty
            ? current.phoneNumber
            : profile?.phone,
        email: current.email.isNotEmpty ? current.email : profile?.email,
        vehicleType: current.vehicleType.isNotEmpty
            ? current.vehicleType
            : profile?.vehicleType,
        vehicleModel: current.vehicleModel.isNotEmpty
            ? current.vehicleModel
            : profile?.vehicleModel,
        vehiclePlateNumber: current.vehiclePlateNumber.isNotEmpty
            ? current.vehiclePlateNumber
            : profile?.vehiclePlateNumber,
        vehicleColor: current.vehicleColor.isNotEmpty
            ? current.vehicleColor
            : profile?.vehicleColor,
        numberOfSeats: current.numberOfSeats > 0
            ? current.numberOfSeats
            : profile?.numberOfSeats,
        cityRegion: current.cityRegion.isNotEmpty
            ? current.cityRegion
            : profile?.cityRegion,
        payoutProvider: current.payoutProvider.isNotEmpty
            ? current.payoutProvider
            : payout?['provider']?.toString(),
        payoutAccountName: current.payoutAccountName.isNotEmpty
            ? current.payoutAccountName
            : payout?['accountName']?.toString(),
        payoutAccountNumber: current.payoutAccountNumber.isNotEmpty
            ? current.payoutAccountNumber
            : payout?['accountNumber']?.toString(),
        nationalIdNumber: current.nationalIdNumber.isNotEmpty
            ? current.nationalIdNumber
            : verification?.nationalIdNumber,
        nationalIdPhotoPath:
            current.nationalIdPhotoPath ?? verification?.nationalIdPath,
        nationalIdBackPhotoPath:
            current.nationalIdBackPhotoPath ?? verification?.nationalIdBackPath,
        driverLicenceNumber: current.driverLicenceNumber.isNotEmpty
            ? current.driverLicenceNumber
            : verification?.licenceNumber,
        driverLicenceExpiryDate:
            current.driverLicenceExpiryDate ?? verification?.licenceExpiry,
        driverLicencePhotoPath:
            current.driverLicencePhotoPath ?? verification?.licencePath,
        selfiePhotoPath: current.selfiePhotoPath ?? verification?.selfiePath,
        regionId: current.regionId ?? profile?.regionId,
        affiliationType: current.affiliationType ?? profile?.affiliationType,
        serviceTypes: current.serviceTypes.isNotEmpty
            ? current.serviceTypes
            : profile?.serviceTypes,
        vehicleCategory: current.vehicleCategory ?? profile?.vehicleCategory,
        acceptedTerms: current.acceptedTerms || uid.isNotEmpty,
      );
      setState(() {});
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final route = await AuthService.instance.finalizeDriverOnboarding(
        RegistrationDraftService.instance.value,
      );
      if (!mounted) return;
      await _showSubmittedDialog();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } catch (error) {
      if (!mounted) return;
      _showError(AuthService.instance.friendlyError(error));
      setState(() => _isSubmitting = false);
    }
  }

  // Submission used to go straight to the dashboard with no acknowledgement at all - from the
  // driver's side that looked identical to a silent failure, even though it had actually
  // succeeded. This blocks on an explicit tap so the confirmation can never be missed by a fast
  // screen transition the way a timed SnackBar could be.
  Future<void> _showSubmittedDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        title: Text(
          DriverCopy.current.t('Application Submitted', 'Candidature envoyée'),
        ),
        content: Text(
          DriverCopy.current.t(
            'Your documents were submitted successfully and are now under '
                'review. We will notify you once verification is complete.',
            "Vos documents ont été envoyés avec succès et sont en cours d'examen. Nous vous informerons dès que la vérification sera terminée.",
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(DriverCopy.current.t('Continue', 'Continuer')),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _edit(String route) {
    Navigator.pushNamed(context, route, arguments: {'returnToReview': true});
  }

  // Group and status labels keep their English identifiers in the data below
  // (used for the icon/color comparisons further down); only the display text
  // rendered via `copy.t`/these helpers is translated.
  String _groupTitleFr(String key) => switch (key) {
    'Account' => 'Compte',
    'Vehicle and payment' => 'Véhicule et paiement',
    'Work relationship' => 'Relation de travail',
    'Identity documents' => "Documents d'identité",
    _ => key,
  };

  String _statusLabel(String value, DriverCopy copy) => switch (value) {
    'Missing' => copy.t('Missing', 'Manquant'),
    'Front and back attached' => copy.t(
      'Front and back attached',
      'Recto et verso ajoutés',
    ),
    'Attached' => copy.t('Attached', 'Ajouté'),
    'Captured live' => copy.t('Captured live', 'Capturé en direct'),
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final draft = RegistrationDraftService.instance.value;
    final copy = DriverCopy.of(context);
    final groups = <(String, IconData, List<(String, String, String)>)>[
      (
        'Account',
        Icons.person_outline_rounded,
        [
          (copy.t('Name', 'Nom'), draft.fullName, RouteNames.profileSetup),
          (
            copy.t('Phone', 'Téléphone'),
            draft.phoneNumber,
            RouteNames.profileSetup,
          ),
          (copy.t('Email', 'E-mail'), draft.email, RouteNames.profileSetup),
        ],
      ),
      (
        'Vehicle and payment',
        Icons.directions_car_outlined,
        [
          (
            copy.t('Ride class', 'Classe de course'),
            _capitalize(draft.vehicleType),
            RouteNames.profileSetup,
          ),
          (
            copy.t('Vehicle', 'Véhicule'),
            draft.vehicleModel,
            RouteNames.profileSetup,
          ),
          (
            copy.t('Plate number', 'Numéro de plaque'),
            draft.vehiclePlateNumber,
            RouteNames.profileSetup,
          ),
          (
            copy.t('Passenger seats', 'Places passagers'),
            '${draft.numberOfSeats}',
            RouteNames.profileSetup,
          ),
          (
            copy.t('Operating city', "Ville d'activité"),
            draft.cityRegion,
            RouteNames.profileSetup,
          ),
          (
            copy.t('Receiving account', 'Compte de réception des paiements'),
            draft.payoutAccountNumber.isEmpty
                ? 'Missing'
                : '${draft.payoutProvider} - ${draft.payoutAccountNumber}',
            RouteNames.profileSetup,
          ),
        ],
      ),
      (
        'Work relationship',
        Icons.work_outline_rounded,
        [
          (
            copy.t('Affiliation', 'Affiliation'),
            DriverTaxonomy.labelFor(
              DriverTaxonomy.affiliations,
              draft.affiliationType,
            ),
            RouteNames.affiliation,
          ),
          (
            copy.t('Operating region', "Région d'activité"),
            DriverTaxonomy.labelFor(DriverTaxonomy.regions, draft.regionId),
            RouteNames.region,
          ),
          (
            copy.t('Services', 'Services'),
            draft.serviceTypes
                .map(
                  (value) => DriverTaxonomy.labelFor(
                    DriverTaxonomy.serviceTypes,
                    value,
                  ),
                )
                .join(', '),
            RouteNames.services,
          ),
          (
            copy.t('Vehicle category', 'Catégorie de véhicule'),
            DriverTaxonomy.labelFor(
              DriverTaxonomy.vehicleCategories,
              draft.vehicleCategory,
            ),
            RouteNames.vehicleCategory,
          ),
        ],
      ),
      (
        'Identity documents',
        Icons.verified_user_outlined,
        [
          (
            copy.t('National ID', "Carte d'identité nationale"),
            draft.nationalIdNumber.isEmpty ||
                    (draft.nationalIdPhotoPath == null &&
                        draft.nationalIdPhotoBytes == null) ||
                    (draft.nationalIdBackPhotoPath == null &&
                        draft.nationalIdBackPhotoBytes == null)
                ? 'Missing'
                : 'Front and back attached',
            RouteNames.nationalId,
          ),
          (
            copy.t("Driver's licence", 'Permis de conduire'),
            draft.driverLicencePhotoPath == null &&
                    draft.driverLicencePhotoBytes == null
                ? 'Missing'
                : 'Attached',
            RouteNames.licence,
          ),
          (
            copy.t('Live selfie', 'Selfie en direct'),
            draft.selfiePhotoPath == null && draft.selfieBytes == null
                ? 'Missing'
                : 'Captured live',
            RouteNames.selfie,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.t('FINAL REVIEW', 'REVUE FINALE'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              Text(
                copy.t('Review your application', 'Vérifiez votre candidature'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 5),
              Text(
                copy.t(
                  'TheRain reviews your identity, licence, vehicle, and fleet relationship separately before enabling rides.',
                  "TheRain examine séparément votre identité, votre permis, votre véhicule et votre relation avec la flotte avant d'activer les courses.",
                ),
              ),
              SizedBox(height: 18),
              for (final group in groups) ...[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconWell(icon: group.$2, size: 40),
                          SizedBox(width: 12),
                          Text(
                            copy.t(group.$1, _groupTitleFr(group.$1)),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      for (final item in group.$3)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: _isSubmitting ? null : () => _edit(item.$3),
                          title: Text(item.$1),
                          subtitle: Text(
                            _statusLabel(
                              item.$2.isEmpty ? 'Missing' : item.$2,
                              copy,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            item.$2.isEmpty || item.$2 == 'Missing'
                                ? Icons.error_rounded
                                // Identity documents: a green check once uploaded, matching the
                                // checklist convention on Vehicle Documents. Other groups (plain
                                // text fields, not uploads) keep the edit-pencil affordance.
                                : (group.$1 == 'Identity documents'
                                      ? Icons.check_circle_rounded
                                      : Icons.edit_outlined),
                            color: item.$2.isEmpty || item.$2 == 'Missing'
                                ? AppColors.danger
                                : (group.$1 == 'Identity documents'
                                      ? AppColors.success
                                      : AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
              ],
              AppCard(
                color: AppColors.primarySoftFor(context),
                child: Row(
                  children: [
                    IconWell(icon: Icons.lock_outline_rounded),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        copy.t(
                          'Files are private and only their Storage paths are '
                              'saved for verification.',
                          'Les fichiers sont privés et seuls leurs chemins de '
                              'stockage sont enregistrés pour la vérification.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              PrimaryButton(
                label: copy.t(
                  'Submit for Verification',
                  'Soumettre pour vérification',
                ),
                icon: Icons.verified_user_outlined,
                isLoading: _isSubmitting,
                onPressed: draft.isComplete ? _submit : null,
              ),
              SizedBox(height: 12),
              AppOutlineButton(
                label: copy.t('Back to application', 'Retour à la candidature'),
                icon: Icons.dashboard_customize_outlined,
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.application,
                        (route) => false,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
