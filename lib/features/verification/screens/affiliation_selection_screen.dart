import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/auth_sync_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/option_card.dart';
import '../../shared/widgets/step_indicator.dart';

/// Phase 5: first of the new canonical-taxonomy onboarding screens
/// (DRIVER_AND_FLEET_CONTRACT.md sections 1, 6; Phase 5 prompt section 21). Independent of
/// vehicle category and service type - selecting "Fleet Driver" here does not by itself grant a
/// fleet membership; it only routes the driver through [RouteNames.fleetJoin] later in this same
/// chain, where the actual invitation/request flow (server-validated) happens.
class AffiliationSelectionScreen extends StatefulWidget {
  const AffiliationSelectionScreen({
    super.key,
    this.driverRepository,
    this.authSyncService,
    this.currentUserId,
  });

  @visibleForTesting
  final DriverRepository? driverRepository;

  @visibleForTesting
  final AuthSyncService? authSyncService;

  @visibleForTesting
  final String? Function()? currentUserId;

  @override
  State<AffiliationSelectionScreen> createState() =>
      _AffiliationSelectionScreenState();
}

class _AffiliationSelectionScreenState
    extends State<AffiliationSelectionScreen> {
  String? _selected;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  bool _profileLoadFailed = false;
  DriverProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!_isLoadingProfile && mounted) {
      setState(() {
        _isLoadingProfile = true;
        _profileLoadFailed = false;
        _error = null;
      });
    }
    final uid =
        widget.currentUserId?.call() ?? AuthService.instance.currentUserId;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _profileLoadFailed = true;
        _error = _loadProfileError;
      });
      return;
    }
    try {
      final profile = await (widget.driverRepository ?? DriverRepository())
          .getProfile(uid);
      if (!mounted) return;
      final persistedAffiliation = _persistedAffiliation(profile);
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
        _profileLoadFailed = false;
        _error = null;
        _selected =
            persistedAffiliation ??
            (profile == null
                ? RegistrationDraftService.instance.value.affiliationType
                : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _profileLoadFailed = true;
        _error = _loadProfileError;
      });
    }
  }

  Future<void> _continue() async {
    if (_isLoadingProfile || _profileLoadFailed || _isSaving) return;
    if (_isAffiliationLocked) {
      setState(() => _error = _lockedMessage);
      return;
    }
    final value = _selected;
    if (value == null) {
      setState(
        () => _error = DriverCopy.current.t(
          'Choose how you will drive with TheRain.',
          'Choisissez comment vous allez conduire avec TheRain.',
        ),
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (value != 'therain_managed') {
        final uid =
            widget.currentUserId?.call() ?? AuthService.instance.currentUserId;
        if (uid == null) {
          throw StateError('Sign in before choosing a driver type.');
        }
        final regionId =
            RegistrationDraftService.instance.value.regionId ??
            _profile?.regionId;
        if (regionId == null || regionId.trim().isEmpty) {
          throw StateError('Choose a region before saving your driver type.');
        }
        await (widget.authSyncService ?? AuthSyncService.instance)
            .saveAffiliation(regionId: regionId, affiliationType: value);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = DriverCopy.current.t(
          'We could not save your driver type. Check your connection and try again.',
          'Nous n’avons pas pu enregistrer votre type de chauffeur. Vérifiez votre connexion et réessayez.',
        );
      });
      return;
    }
    if (!mounted) return;
    RegistrationDraftService.instance.updateAffiliation(value);
    setState(() => _isSaving = false);
    Navigator.pushNamed(
      context,
      _returnToReview
          ? RouteNames.review
          : value == 'fleet'
          ? RouteNames.region
          : RouteNames.profileSetup,
      arguments: value == 'fleet' && !_returnToReview
          ? const {'continueToProfileSetup': true}
          : null,
    );
  }

  String? _persistedAffiliation(DriverProfile? profile) {
    final affiliation = profile?.affiliationType?.trim();
    if (affiliation != null && affiliation.isNotEmpty) return affiliation;
    if (profile == null) return null;
    final legacyType = profile.driverType.trim().toLowerCase();
    if (legacyType == 'fleet') return 'fleet';
    if (legacyType == 'company' || legacyType == 'enterprise') {
      return 'therain_managed';
    }
    if (profile.hasSubmittedApplication && legacyType == 'individual') {
      return 'independent';
    }
    return null;
  }

  bool get _isAffiliationLocked => _profile?.hasSubmittedApplication ?? false;

  bool get _isExistingManagedDriver =>
      _persistedAffiliation(_profile) == 'therain_managed';

  String get _loadProfileError => DriverCopy.current.t(
    'We could not verify your application status. Please retry before continuing.',
    'Nous n’avons pas pu vérifier le statut de votre candidature. Réessayez avant de continuer.',
  );

  String get _lockedMessage => DriverCopy.current.t(
    'Your application has already been submitted or approved. Your driver type can no longer be changed.',
    'Votre candidature a déjà été soumise ou approuvée. Votre type de chauffeur ne peut plus être modifié.',
  );

  bool get _returnToReview {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['returnToReview'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepIndicator(
                current: 2,
                total: 4,
                labels: [
                  l.t('Region', 'Région'),
                  l.t('Affiliation', 'Affiliation'),
                  l.t('Services', 'Services'),
                  l.t('Vehicle', 'Véhicule'),
                ],
              ),
              SizedBox(height: 26),
              Text(
                l.t(
                  'How will you drive with TheRain?',
                  'Comment allez-vous conduire avec TheRain ?',
                ),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 6),
              Text(
                l.t(
                  'Choose whether you will drive independently or with a Fleet.',
                  'Choisissez si vous conduirez en indépendant ou avec une flotte.',
                ),
              ),
              SizedBox(height: 22),
              if (_isLoadingProfile)
                const Center(child: CircularProgressIndicator())
              else if (_isExistingManagedDriver)
                Text(
                  l.t(
                    'This account is managed by TheRain. Contact support if you need help with your account.',
                    'Ce compte est géré par TheRain. Contactez le support si vous avez besoin d’aide.',
                  ),
                )
              else if (_isAffiliationLocked)
                Text(
                  _lockedMessage,
                  style: TextStyle(color: AppColors.textSecondaryFor(context)),
                )
              else
                for (final option in DriverTaxonomy.affiliations.where(
                  (option) =>
                      option.value == 'independent' || option.value == 'fleet',
                )) ...[
                  OptionCard(
                    label: option.localizedLabel(l.isFrench),
                    subtitle: DriverTaxonomy.affiliationDescriptionFor(
                      option.value,
                      isFrench: l.isFrench,
                    ),
                    selected: _selected == option.value,
                    onTap: () {
                      if (_isSaving) return;
                      setState(() {
                        _selected = option.value;
                        _error = null;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                ],
              if (_error != null) ...[
                SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              SizedBox(height: 18),
              PrimaryButton(
                label: l.t('Continue', 'Continuer'),
                isLoading: _isSaving,
                onPressed:
                    _isLoadingProfile ||
                        _profileLoadFailed ||
                        _isAffiliationLocked
                    ? null
                    : _continue,
              ),
              if (_profileLoadFailed)
                TextButton(
                  onPressed: _loadProfile,
                  child: Text(l.t('Retry', 'Réessayer')),
                ),
              SizedBox(height: 12),
              AppOutlineButton(
                label: l.t('Back', 'Retour'),
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
