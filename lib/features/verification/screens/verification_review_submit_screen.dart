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

  @override
  Widget build(BuildContext context) {
    final draft = RegistrationDraftService.instance.value;
    final groups = <(String, IconData, List<(String, String, String)>)>[
      (
        'Account',
        Icons.person_outline_rounded,
        [
          ('Name', draft.fullName, RouteNames.profileSetup),
          ('Phone', draft.phoneNumber, RouteNames.profileSetup),
          ('Email', draft.email, RouteNames.profileSetup),
        ],
      ),
      (
        'Vehicle and payment',
        Icons.directions_car_outlined,
        [
          (
            'Ride class',
            _capitalize(draft.vehicleType),
            RouteNames.profileSetup,
          ),
          ('Vehicle', draft.vehicleModel, RouteNames.profileSetup),
          ('Plate number', draft.vehiclePlateNumber, RouteNames.profileSetup),
          (
            'Passenger seats',
            '${draft.numberOfSeats}',
            RouteNames.profileSetup,
          ),
          ('Operating city', draft.cityRegion, RouteNames.profileSetup),
          (
            'Receiving account',
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
            'Affiliation',
            DriverTaxonomy.labelFor(
              DriverTaxonomy.affiliations,
              draft.affiliationType,
            ),
            RouteNames.affiliation,
          ),
          (
            'Operating region',
            DriverTaxonomy.labelFor(DriverTaxonomy.regions, draft.regionId),
            RouteNames.region,
          ),
          (
            'Services',
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
            'Vehicle category',
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
            "Driver's licence",
            draft.driverLicencePhotoPath == null &&
                    draft.driverLicencePhotoBytes == null
                ? 'Missing'
                : 'Attached',
            RouteNames.licence,
          ),
          (
            'Live selfie',
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
                'FINAL REVIEW',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Review your application',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 5),
              Text(
                'TheRain reviews your identity, licence, vehicle, and fleet relationship separately before enabling rides.',
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
                            group.$1,
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
                            item.$2.isEmpty ? 'Missing' : item.$2,
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
                        'Files are private and only their Storage paths are '
                        'saved for verification.',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              PrimaryButton(
                label: 'Submit for Verification',
                icon: Icons.verified_user_outlined,
                isLoading: _isSubmitting,
                onPressed: draft.isComplete ? _submit : null,
              ),
              SizedBox(height: 12),
              AppOutlineButton(
                label: 'Back to application',
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
