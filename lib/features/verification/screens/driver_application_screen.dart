import 'package:flutter/material.dart';

import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../data/models/driver_verification.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/repositories/driver_verification_repository.dart';
import '../../../data/repositories/fleet_membership_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';

class DriverApplicationScreen extends StatefulWidget {
  const DriverApplicationScreen({super.key});

  @override
  State<DriverApplicationScreen> createState() =>
      _DriverApplicationScreenState();
}

class _DriverApplicationScreenState extends State<DriverApplicationScreen> {
  final _driverRepository = DriverRepository();
  final _verificationRepository = DriverVerificationRepository();
  final _membershipRepository = FleetMembershipRepository();

  DriverProfile? _profile;
  DriverVerification? _verification;
  Map<String, dynamic>? _membership;
  bool _isLoading = true;
  bool _isSigningOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Log in to continue your driver application.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object?>([
        _driverRepository.getProfile(uid),
        _verificationRepository.getVerification(uid),
        _driverRepository.getDefaultPayoutAccount(uid),
      ]);
      final profile = results[0] as DriverProfile?;
      final verification = results[1] as DriverVerification?;
      final payout = results[2] as Map<String, dynamic>?;

      final current = RegistrationDraftService.instance.value;
      Map<String, dynamic>? membership;
      final expectsFleet =
          current.affiliationType == 'fleet' ||
          profile?.affiliationType == 'fleet' ||
          profile?.effectiveFleetId != null;
      if (expectsFleet) {
        try {
          membership = await _membershipRepository.getMyMembership();
        } catch (_) {
          // The rest of the application remains available while fleet status retries.
        }
      }

      final hasLocalVehicleChanges =
          current.vehicleModel.isNotEmpty ||
          current.vehiclePlateNumber.isNotEmpty ||
          current.cityRegion.isNotEmpty;
      RegistrationDraftService.instance.draft.value = current.copyWith(
        fullName: current.fullName.isNotEmpty
            ? current.fullName
            : profile?.fullName,
        phoneNumber: current.phoneNumber.isNotEmpty
            ? current.phoneNumber
            : profile?.phone,
        email: current.email.isNotEmpty ? current.email : profile?.email,
        vehicleType: hasLocalVehicleChanges
            ? current.vehicleType
            : _notEmpty(profile?.vehicleType) ?? current.vehicleType,
        vehicleModel: current.vehicleModel.isNotEmpty
            ? current.vehicleModel
            : profile?.vehicleModel,
        vehiclePlateNumber: current.vehiclePlateNumber.isNotEmpty
            ? current.vehiclePlateNumber
            : profile?.vehiclePlateNumber,
        vehicleColor: hasLocalVehicleChanges
            ? current.vehicleColor
            : _notEmpty(profile?.vehicleColor) ?? current.vehicleColor,
        numberOfSeats: hasLocalVehicleChanges
            ? current.numberOfSeats
            : (profile?.numberOfSeats ?? 0) > 0
            ? profile!.numberOfSeats
            : current.numberOfSeats,
        cityRegion: current.cityRegion.isNotEmpty
            ? current.cityRegion
            : profile?.cityRegion,
        payoutProvider: current.payoutAccountNumber.isNotEmpty
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

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _verification = verification;
        _membership = membership;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AuthService.instance.friendlyError(error);
      });
    }
  }

  String? _notEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  bool get _vehicleAndPayoutComplete {
    final draft = RegistrationDraftService.instance.value;
    return draft.fullName.trim().isNotEmpty &&
        draft.phoneNumber.trim().isNotEmpty &&
        draft.email.trim().isNotEmpty &&
        draft.vehicleModel.trim().isNotEmpty &&
        draft.vehiclePlateNumber.trim().isNotEmpty &&
        draft.numberOfSeats > 0 &&
        draft.cityRegion.trim().isNotEmpty &&
        draft.payoutProvider.trim().isNotEmpty &&
        draft.payoutAccountName.trim().isNotEmpty &&
        draft.payoutAccountNumber.trim().isNotEmpty;
  }

  bool get _workSetupComplete {
    final draft = RegistrationDraftService.instance.value;
    return (draft.regionId?.trim().isNotEmpty ?? false) &&
        (draft.affiliationType?.trim().isNotEmpty ?? false) &&
        draft.serviceTypes.isNotEmpty &&
        (draft.vehicleCategory?.trim().isNotEmpty ?? false);
  }

  bool get _documentsComplete {
    final draft = RegistrationDraftService.instance.value;
    return draft.nationalIdNumber.trim().isNotEmpty &&
        (draft.nationalIdPhotoPath != null ||
            draft.nationalIdPhotoBytes != null) &&
        (draft.nationalIdBackPhotoPath != null ||
            draft.nationalIdBackPhotoBytes != null) &&
        draft.driverLicenceNumber.trim().isNotEmpty &&
        draft.driverLicenceExpiryDate != null &&
        (draft.driverLicencePhotoPath != null ||
            draft.driverLicencePhotoBytes != null) &&
        (draft.selfiePhotoPath != null || draft.selfieBytes != null);
  }

  int get _completedSections =>
      1 +
      (_vehicleAndPayoutComplete ? 1 : 0) +
      (_workSetupComplete ? 1 : 0) +
      (_documentsComplete ? 1 : 0);

  String get _nextRoute {
    if (!_vehicleAndPayoutComplete) return RouteNames.profileSetup;
    if (!_workSetupComplete) return RouteNames.region;
    if (!_documentsComplete) return RouteNames.nationalId;
    return RouteNames.review;
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) await _loadApplication();
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.onboarding,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DriverAppBar(
        title: 'Driver application',
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.contactSupport),
            icon: Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const LoadingState(label: 'Loading your application...')
            : RefreshIndicator(
                onRefresh: _loadApplication,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                  child: _buildContent(context),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (AuthService.instance.currentUserId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error ?? 'Log in to continue your driver application.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          PrimaryButton(
            label: 'Log in',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.login,
              (_) => false,
            ),
          ),
        ],
      );
    }

    final draft = RegistrationDraftService.instance.value;
    final progress = _completedSections / 4;
    final affiliation = DriverTaxonomy.labelFor(
      DriverTaxonomy.affiliations,
      draft.affiliationType,
    );
    final vehicleSummary = _vehicleAndPayoutComplete
        ? '${draft.vehicleModel} | ${draft.vehiclePlateNumber}'
        : 'Add your vehicle and receiving account';
    final workSummary = _workSetupComplete
        ? '$affiliation | ${DriverTaxonomy.labelFor(DriverTaxonomy.regions, draft.regionId)}'
        : 'Choose your region, services, vehicle type, and affiliation';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set up once. Drive after approval.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 7),
        Text(
          'Your account is ready. Complete the sections below now or resume later.',
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  backgroundColor: AppColors.borderFor(context),
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              '$_completedSections of 4',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SizedBox(height: 22),
        _SetupSection(
          icon: Icons.check_circle_outline_rounded,
          title: 'Account created',
          subtitle: '${draft.fullName}\n${draft.phoneNumber}',
          complete: true,
        ),
        SizedBox(height: 12),
        _SetupSection(
          icon: Icons.directions_car_outlined,
          title: 'Vehicle and payment',
          subtitle: vehicleSummary,
          complete: _vehicleAndPayoutComplete,
          onTap: () => _open(RouteNames.profileSetup),
        ),
        SizedBox(height: 12),
        _SetupSection(
          icon: Icons.work_outline_rounded,
          title: 'How you will drive',
          subtitle: workSummary,
          complete: _workSetupComplete,
          onTap: () => _open(RouteNames.region),
        ),
        SizedBox(height: 12),
        _SetupSection(
          icon: Icons.verified_user_outlined,
          title: 'Identity documents',
          subtitle: _documentSummary,
          complete: _documentsComplete,
          onTap: () => _open(RouteNames.nationalId),
        ),
        SizedBox(height: 24),
        const SectionHeader(title: 'Driver relationship'),
        SizedBox(height: 10),
        AppCard(
          child: Row(
            children: [
              IconWell(
                icon: draft.affiliationType == 'fleet'
                    ? Icons.groups_outlined
                    : Icons.person_pin_circle_outlined,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      affiliation.isEmpty ? 'Not selected yet' : affiliation,
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(_relationshipSummary),
                  ],
                ),
              ),
              if (draft.affiliationType == 'fleet')
                IconButton(
                  tooltip: 'Manage fleet relationship',
                  onPressed: () => _open(
                    _membership == null
                        ? RouteNames.fleetJoin
                        : RouteNames.membershipPending,
                  ),
                  icon: Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: 14),
          Text(_error!, style: TextStyle(color: AppColors.danger)),
        ],
        SizedBox(height: 24),
        PrimaryButton(
          label: RegistrationDraftService.instance.value.isComplete
              ? 'Review and submit'
              : 'Continue setup',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => _open(_nextRoute),
        ),
        SizedBox(height: 10),
        Text(
          'You cannot go online or receive rides until TheRain approves your application, identity documents, and vehicle.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        SizedBox(height: 12),
        TextButton.icon(
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.logout_rounded),
          label: Text('Save and sign out'),
        ),
      ],
    );
  }

  String get _documentSummary {
    if (_verification?.status.name == 'rejected' ||
        _verification?.status.name == 'resubmissionRequired') {
      return 'Review feedback and replace the requested files';
    }
    if (_documentsComplete) {
      return 'National ID, driver licence, and live selfie attached';
    }
    return 'Add your national ID, driver licence, and live selfie';
  }

  String get _relationshipSummary {
    final draft = RegistrationDraftService.instance.value;
    if (draft.affiliationType != 'fleet') {
      return draft.affiliationType == 'therain_managed'
          ? 'Managed directly by TheRain'
          : 'No fleet controls this driver account';
    }
    final status = _membership?['status']?.toString();
    final fleetName = _profile?.fleetName;
    final fleetId =
        _membership?['fleetId']?.toString() ?? _profile?.currentFleetId;
    final identity = _notEmpty(fleetName) ?? _notEmpty(fleetId) ?? 'Fleet';
    return status == null
        ? '$identity | Link not confirmed'
        : '$identity | ${_membershipStatusLabel(status)}';
  }

  String _membershipStatusLabel(String status) {
    return switch (status.toLowerCase()) {
      'invited' => 'Invitation received',
      'pending' => 'Awaiting approval',
      'active' => 'Active membership',
      'suspended' => 'Membership suspended',
      _ => status,
    };
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.complete,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool complete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconWell(
            icon: icon,
            color: complete ? AppColors.success : AppColors.primary,
            background: complete
                ? AppColors.successSoftFor(context)
                : AppColors.primarySoftFor(context),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(subtitle),
              ],
            ),
          ),
          SizedBox(width: 8),
          StatusBadge(
            label: complete ? 'Done' : 'Start',
            tone: complete ? BadgeTone.success : BadgeTone.neutral,
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
