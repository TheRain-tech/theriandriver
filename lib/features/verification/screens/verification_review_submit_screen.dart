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
import '../../shared/widgets/step_indicator.dart';

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
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } catch (error) {
      if (!mounted) return;
      _showError(AuthService.instance.friendlyError(error));
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _edit(String route) {
    Navigator.pushNamed(context, route, arguments: {'returnToReview': true});
  }

  void _editStep(int step) {
    final route = switch (step) {
      1 => RouteNames.profileSetup,
      2 => RouteNames.profileSetup,
      3 => RouteNames.nationalId,
      4 => RouteNames.licence,
      _ => RouteNames.selfie,
    };
    _edit(route);
  }

  @override
  Widget build(BuildContext context) {
    final draft = RegistrationDraftService.instance.value;
    final details = <(IconData, String, String, String)>[
      (
        Icons.person_rounded,
        'Personal Info',
        draft.fullName,
        RouteNames.profileSetup,
      ),
      (
        Icons.phone_rounded,
        'Phone Number',
        draft.phoneNumber,
        RouteNames.profileSetup,
      ),
      (Icons.email_rounded, 'Email', draft.email, RouteNames.profileSetup),
      (
        Icons.directions_car_rounded,
        'Vehicle Info',
        _capitalize(draft.vehicleType),
        RouteNames.profileSetup,
      ),
      (
        Icons.car_repair_rounded,
        'Vehicle Model',
        draft.vehicleModel,
        RouteNames.profileSetup,
      ),
      (
        Icons.pin_outlined,
        'Plate Number',
        draft.vehiclePlateNumber,
        RouteNames.profileSetup,
      ),
      (
        Icons.event_seat_rounded,
        'Seats',
        '${draft.numberOfSeats}',
        RouteNames.profileSetup,
      ),
      (
        Icons.location_city_rounded,
        'City / Region',
        draft.cityRegion,
        RouteNames.profileSetup,
      ),
      (
        Icons.badge_outlined,
        'Affiliation',
        DriverTaxonomy.labelFor(
          DriverTaxonomy.affiliations,
          draft.affiliationType,
        ),
        RouteNames.affiliation,
      ),
      (
        Icons.map_outlined,
        'Operating Region',
        DriverTaxonomy.labelFor(DriverTaxonomy.regions, draft.regionId),
        RouteNames.region,
      ),
      (
        Icons.local_shipping_outlined,
        'Services',
        draft.serviceTypes
            .map(
              (value) =>
                  DriverTaxonomy.labelFor(DriverTaxonomy.serviceTypes, value),
            )
            .join(', '),
        RouteNames.services,
      ),
      (
        Icons.directions_car_filled_outlined,
        'Vehicle Category',
        DriverTaxonomy.labelFor(
          DriverTaxonomy.vehicleCategories,
          draft.vehicleCategory,
        ),
        RouteNames.vehicleCategory,
      ),
      (
        Icons.badge_rounded,
        'National ID',
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
        Icons.credit_card_rounded,
        "Driver's Licence",
        draft.driverLicencePhotoPath == null &&
                draft.driverLicencePhotoBytes == null
            ? 'Missing'
            : 'Attached',
        RouteNames.licence,
      ),
      (
        Icons.face_rounded,
        'Live Selfie',
        draft.selfiePhotoPath == null && draft.selfieBytes == null
            ? 'Missing'
            : 'Captured live',
        RouteNames.selfie,
      ),
      (
        Icons.account_balance_wallet_rounded,
        'Receiving Account',
        draft.payoutAccountNumber.isEmpty
            ? 'Missing'
            : '${draft.payoutProvider} - ${draft.payoutAccountNumber}',
        RouteNames.profileSetup,
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
              StepIndicator(
                current: 5,
                labels: const [
                  'Account',
                  'Profile',
                  'Vehicle',
                  'Docs',
                  'Review',
                ],
                onStepTap: _isSubmitting ? null : _editStep,
              ),
              const SizedBox(height: 22),
              Text(
                'Review & Submit',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              const Text(
                'Please confirm your details before submission.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < details.length; i++) ...[
                      ListTile(
                        onTap: _isSubmitting
                            ? null
                            : () => _edit(details[i].$4),
                        leading: IconWell(icon: details[i].$1, size: 42),
                        title: Text(
                          details[i].$2,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          details[i].$3.isEmpty ? 'Missing' : details[i].$3,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tap to edit',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              details[i].$3.isEmpty ||
                                      details[i].$3 == 'Missing'
                                  ? Icons.error_outline_rounded
                                  : Icons.edit_outlined,
                              color:
                                  details[i].$3.isEmpty ||
                                      details[i].$3 == 'Missing'
                                  ? AppColors.danger
                                  : AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      if (i < details.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppCard(
                color: AppColors.primarySoft,
                child: Row(
                  children: [
                    IconWell(icon: Icons.lock_outline_rounded),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Files are private and only their Storage paths are '
                        'saved for verification.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Submit for Verification',
                icon: Icons.verified_user_outlined,
                isLoading: _isSubmitting,
                onPressed: draft.isComplete ? _submit : null,
              ),
              const SizedBox(height: 12),
              AppOutlineButton(
                label: 'Edit Details',
                icon: Icons.edit_outlined,
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.profileSetup,
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
