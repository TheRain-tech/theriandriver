import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
          _error = DriverCopy.current.t(
            'Log in to continue your driver application.',
            'Connectez-vous pour continuer votre candidature de chauffeur.',
          );
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
    final l = DriverCopy.of(context);
    return Scaffold(
      appBar: DriverAppBar(
        title: l.t('Driver application', 'Candidature chauffeur'),
        actions: [
          IconButton(
            tooltip: l.t('Help', 'Aide'),
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.contactSupport),
            icon: Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? LoadingState(
                label: l.t(
                  'Loading your application...',
                  'Chargement de votre candidature...',
                ),
              )
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
    final l = DriverCopy.of(context);
    if (AuthService.instance.currentUserId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error ??
                l.t(
                  'Log in to continue your driver application.',
                  'Connectez-vous pour continuer votre candidature de chauffeur.',
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          PrimaryButton(
            label: l.t('Log in', 'Se connecter'),
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
      isFrench: l.isFrench,
    );
    final vehicleSummary = _vehicleAndPayoutComplete
        ? '${draft.vehicleModel} | ${draft.vehiclePlateNumber}'
        : l.t(
            'Add your vehicle and receiving account',
            'Ajoutez votre véhicule et votre compte de réception',
          );
    final workSummary = _workSetupComplete
        ? '$affiliation | ${DriverTaxonomy.labelFor(DriverTaxonomy.regions, draft.regionId, isFrench: l.isFrench)}'
        : l.t(
            'Choose your region, services, vehicle type, and affiliation',
            'Choisissez votre région, vos services, votre type de véhicule et votre affiliation',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.t('Set up once. Drive after approval.', 'Configurez une fois. Conduisez après approbation.'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 7),
        Text(
          l.t(
            'Your account is ready. Complete the sections below now or resume later.',
            'Votre compte est prêt. Complétez les sections ci-dessous maintenant ou reprenez plus tard.',
          ),
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
              l.t('$_completedSections of 4', '$_completedSections sur 4'),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SizedBox(height: 22),
        _SetupSection(
          icon: Icons.check_circle_outline_rounded,
          title: l.t('Account created', 'Compte créé'),
          subtitle: '${draft.fullName}\n${draft.phoneNumber}',
          complete: true,
        ),
        SizedBox(height: 12),
        _SetupSection(
          icon: Icons.directions_car_outlined,
          title: l.t('Vehicle and payment', 'Véhicule et paiement'),
          subtitle: vehicleSummary,
          complete: _vehicleAndPayoutComplete,
          onTap: () => _open(RouteNames.profileSetup),
        ),
        SizedBox(height: 12),
        _SetupSection(
          icon: Icons.work_outline_rounded,
          title: l.t('How you will drive', 'Comment vous conduirez'),
          subtitle: workSummary,
          complete: _workSetupComplete,
          onTap: () => _open(RouteNames.region),
        ),
        SizedBox(height: 12),
        _SetupSection(
          icon: Icons.verified_user_outlined,
          title: l.t('Identity documents', 'Documents d\'identité'),
          subtitle: _documentSummary(l),
          complete: _documentsComplete,
          onTap: () => _open(RouteNames.nationalId),
        ),
        SizedBox(height: 24),
        SectionHeader(title: l.t('Driver relationship', 'Relation chauffeur')),
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
                      affiliation.isEmpty
                          ? l.t('Not selected yet', 'Pas encore sélectionné')
                          : affiliation,
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(_relationshipSummary(l)),
                  ],
                ),
              ),
              if (draft.affiliationType == 'fleet')
                IconButton(
                  tooltip: l.t(
                    'Manage fleet relationship',
                    'Gérer la relation avec la flotte',
                  ),
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
              ? l.t('Review and submit', 'Vérifier et soumettre')
              : l.t('Continue setup', 'Continuer la configuration'),
          icon: Icons.arrow_forward_rounded,
          onPressed: () => _open(_nextRoute),
        ),
        SizedBox(height: 10),
        Text(
          l.t(
            'You cannot go online or receive rides until TheRain approves your application, identity documents, and vehicle.',
            'Vous ne pouvez pas passer en ligne ni recevoir de courses tant que TheRain n\'a pas approuvé votre candidature, vos documents d\'identité et votre véhicule.',
          ),
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
          label: Text(l.t('Save and sign out', 'Enregistrer et se déconnecter')),
        ),
      ],
    );
  }

  String _documentSummary(DriverCopy l) {
    if (_verification?.status.name == 'rejected' ||
        _verification?.status.name == 'resubmissionRequired') {
      return l.t(
        'Review feedback and replace the requested files',
        'Consultez les commentaires et remplacez les fichiers demandés',
      );
    }
    if (_documentsComplete) {
      return l.t(
        'National ID, driver licence, and live selfie attached',
        'Carte d\'identité, permis de conduire et selfie en direct joints',
      );
    }
    return l.t(
      'Add your national ID, driver licence, and live selfie',
      'Ajoutez votre carte d\'identité, votre permis de conduire et un selfie en direct',
    );
  }

  String _relationshipSummary(DriverCopy l) {
    final draft = RegistrationDraftService.instance.value;
    if (draft.affiliationType != 'fleet') {
      return draft.affiliationType == 'therain_managed'
          ? l.t('Managed directly by TheRain', 'Géré directement par TheRain')
          : l.t(
              'No fleet controls this driver account',
              'Aucune flotte ne contrôle ce compte chauffeur',
            );
    }
    final status = _membership?['status']?.toString();
    final fleetName = _profile?.fleetName;
    final fleetId =
        _membership?['fleetId']?.toString() ?? _profile?.currentFleetId;
    final identity =
        _notEmpty(fleetName) ?? _notEmpty(fleetId) ?? l.t('Fleet', 'Flotte');
    return status == null
        ? '$identity | ${l.t('Link not confirmed', 'Lien non confirmé')}'
        : '$identity | ${_membershipStatusLabel(status, l)}';
  }

  String _membershipStatusLabel(String status, DriverCopy l) {
    return switch (status.toLowerCase()) {
      'invited' => l.t('Invitation received', 'Invitation reçue'),
      'pending' => l.t('Awaiting approval', 'En attente d\'approbation'),
      'active' => l.t('Active membership', 'Adhésion active'),
      'suspended' => l.t('Membership suspended', 'Adhésion suspendue'),
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
            label: complete
                ? DriverCopy.of(context).t('Done', 'Terminé')
                : DriverCopy.of(context).t('Start', 'Commencer'),
            tone: complete ? BadgeTone.success : BadgeTone.neutral,
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
