import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
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

  @override
  Widget build(BuildContext context) {
    final draft = RegistrationDraftService.instance.value;
    final details = <(IconData, String, String)>[
      (Icons.person_rounded, 'Full Name', draft.fullName),
      (Icons.phone_rounded, 'Phone Number', draft.phoneNumber),
      (Icons.email_rounded, 'Email', draft.email),
      (
        Icons.directions_car_rounded,
        'Vehicle Type',
        _capitalize(draft.vehicleType),
      ),
      (Icons.car_repair_rounded, 'Vehicle Model', draft.vehicleModel),
      (Icons.pin_outlined, 'Plate Number', draft.vehiclePlateNumber),
      (Icons.event_seat_rounded, 'Seats', '${draft.numberOfSeats}'),
      (Icons.location_city_rounded, 'City / Region', draft.cityRegion),
      (
        Icons.badge_rounded,
        'National ID',
        draft.nationalIdPhotoPath == null && draft.nationalIdPhotoBytes == null
            ? 'Missing'
            : 'Attached',
      ),
      (
        Icons.credit_card_rounded,
        "Driver's Licence",
        draft.driverLicencePhotoPath == null &&
                draft.driverLicencePhotoBytes == null
            ? 'Missing'
            : 'Attached',
      ),
      (
        Icons.face_rounded,
        'Live Selfie',
        draft.selfiePhotoPath == null && draft.selfieBytes == null
            ? 'Missing'
            : 'Captured live',
      ),
      (
        Icons.account_balance_wallet_rounded,
        'Receiving Account',
        draft.payoutAccountNumber.isEmpty
            ? 'Missing'
            : '${draft.payoutProvider} - ${draft.payoutAccountNumber}',
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
              const StepIndicator(
                current: 5,
                labels: ['Account', 'Profile', 'Vehicle', 'Docs', 'Review'],
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
                        trailing: Icon(
                          details[i].$3.isEmpty || details[i].$3 == 'Missing'
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color:
                              details[i].$3.isEmpty ||
                                  details[i].$3 == 'Missing'
                              ? AppColors.danger
                              : AppColors.success,
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
