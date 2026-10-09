import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../data/models/driver_verification.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/repositories/driver_verification_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_verification_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  final _driverRepository = DriverRepository();
  final _verificationRepository = DriverVerificationRepository();
  StreamSubscription<DriverProfile?>? _profileSubscription;
  DriverProfile? _profile;
  Object? _streamError;
  bool _isSigningOut = false;

  String? get _uid => AuthService.instance.currentUserId;

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
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.instance.friendlyError(error))),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid == null) return;
    _profileSubscription = _driverRepository
        .watchProfile(uid)
        .listen(
          _onProfile,
          onError: (Object error) {
            if (mounted) setState(() => _streamError = error);
          },
        );
  }

  void _onProfile(DriverProfile? profile) {
    if (!mounted || profile == null) return;
    DriverVerificationService.instance.syncStatus(profile.verificationStatus);
    setState(() {
      _profile = profile;
      _streamError = null;
    });
    if (profile.isWaitingForRegionLaunch || profile.isSuspended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          profile.isSuspended ? RouteNames.suspended : RouteNames.comingSoon,
          (route) => false,
        );
      });
    } else if (profile.verificationStatus ==
        DriverVerificationStatus.approved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.approved,
          (route) => false,
        );
      });
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final uid = _uid;
    final status =
        _profile?.verificationStatus ?? DriverVerificationStatus.pending;
    final needsResubmission =
        status == DriverVerificationStatus.rejected ||
        status == DriverVerificationStatus.resubmissionRequired;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppLogo(compact: true)),
              SizedBox(height: 34),
              Container(
                height: 230,
                decoration: BoxDecoration(
                  color: needsResubmission
                      ? AppColors.dangerSoftFor(context)
                      : AppColors.primarySoftFor(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  needsResubmission
                      ? Icons.assignment_late_outlined
                      : Icons.manage_search_rounded,
                  size: 130,
                  color: needsResubmission
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),
              SizedBox(height: 30),
              Text(
                needsResubmission
                    ? copy.t('Documents Need Attention', 'Documents à corriger')
                    : copy.t('Verification Pending', 'Vérification en cours'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: 12),
              Text(
                needsResubmission
                    ? copy.t(
                        'Review the feedback below, update your documents, and '
                            'submit them again.',
                        'Consultez les commentaires ci-dessous, mettez à jour '
                            'vos documents, puis soumettez-les à nouveau.',
                      )
                    : copy.t(
                        'Your documents were submitted successfully. This page '
                            'updates automatically when an administrator reviews '
                            'your account.',
                        "Vos documents ont bien été soumis. Cette page se met à "
                            "jour automatiquement dès qu'un administrateur "
                            "examine votre compte.",
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 24),
              AppCard(
                child: Row(
                  children: [
                    IconWell(
                      icon: needsResubmission
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      size: 54,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(copy.t('Status', 'Statut')),
                          SizedBox(height: 3),
                          Text(
                            _statusLabel(
                              copy,
                              status,
                              _profile?.lifecycleStatus,
                            ),
                            style: TextStyle(
                              color: needsResubmission
                                  ? AppColors.danger
                                  : AppColors.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: needsResubmission
                          ? copy.t('Action Needed', 'Action requise')
                          : copy.t('In Review', "En cours d'examen"),
                      tone: needsResubmission
                          ? BadgeTone.danger
                          : BadgeTone.warning,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              _buildRelationshipCard(copy),
              if (uid != null) ...[
                SizedBox(height: 14),
                StreamBuilder<DriverVerification?>(
                  stream: _verificationRepository.watchVerification(uid),
                  builder: (context, snapshot) {
                    return _buildDocumentsCard(
                      copy,
                      snapshot.data,
                      needsResubmission: needsResubmission,
                    );
                  },
                ),
              ],
              if (_streamError != null) ...[
                SizedBox(height: 14),
                Text(
                  copy.t(
                    'The live review status is temporarily unavailable. '
                        'Check your connection and try again.',
                    "Le statut d'examen en direct est temporairement "
                        'indisponible. Vérifiez votre connexion et réessayez.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
              SizedBox(height: 22),
              PrimaryButton(
                label: needsResubmission
                    ? copy.t(
                        'Update Verification Documents',
                        'Mettre à jour les documents de vérification',
                      )
                    : copy.t(
                        'Awaiting Administrator Review',
                        "En attente de l'examen par un administrateur",
                      ),
                onPressed: needsResubmission
                    ? () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.application,
                        (route) => false,
                      )
                    : null,
              ),
              SizedBox(height: 8),
              Text(
                copy.t(
                  'Ride access remains disabled until administrator approval.',
                  "L'accès aux courses reste désactivé jusqu'à l'approbation "
                      "d'un administrateur.",
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.contactSupport),
                icon: Icon(Icons.chat_bubble_outline_rounded),
                label: Text(copy.t('Contact Support', 'Contacter le support')),
              ),
              SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isSigningOut ? null : _signOut,
                icon: _isSigningOut
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(Icons.logout_rounded),
                label: Text(
                  copy.t('Sign Out of Account', 'Se déconnecter du compte'),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(
    DriverCopy copy,
    DriverVerificationStatus status,
    String? lifecycleStatus,
  ) {
    final lifecycle = lifecycleStatus?.toUpperCase();
    if (lifecycle == 'APPOINTMENT_SCHEDULED') {
      return copy.t('Appointment Scheduled', 'Rendez-vous programmé');
    }
    if (lifecycle == 'APPOINTMENT_COMPLETED') {
      return copy.t('Appointment Completed', 'Rendez-vous terminé');
    }
    if (lifecycle == 'UNDER_VERIFICATION') {
      return copy.t('Under Verification', 'En cours de vérification');
    }
    if (lifecycle == 'REJECTED') return copy.t('Rejected', 'Rejeté');
    if (lifecycle == 'APPROVED' || lifecycle == 'ACTIVE') {
      return copy.t('Approved', 'Approuvé');
    }

    return switch (status) {
      DriverVerificationStatus.rejected => copy.t('Rejected', 'Rejeté'),
      DriverVerificationStatus.resubmissionRequired => copy.t(
        'Resubmission Required',
        'Nouvelle soumission requise',
      ),
      DriverVerificationStatus.approved => copy.t('Approved', 'Approuvé'),
      _ => copy.t('Pending Review', "En attente d'examen"),
    };
  }

  Widget _buildRelationshipCard(DriverCopy copy) {
    final profile = _profile;
    final affiliation = DriverTaxonomy.labelFor(
      DriverTaxonomy.affiliations,
      profile?.affiliationType,
    );
    final fleetId = profile?.currentFleetId ?? profile?.fleetId;
    final isFleet =
        profile?.affiliationType == 'fleet' ||
        (fleetId != null && fleetId.trim().isNotEmpty);
    final relationship = isFleet
        ? profile?.fleetName ??
              (fleetId == null || fleetId.isEmpty
                  ? copy.t(
                      'Fleet link awaiting confirmation',
                      'Lien avec le parc en attente de confirmation',
                    )
                  : copy.t('Fleet $fleetId', 'Parc $fleetId'))
        : profile?.affiliationType == 'therain_managed'
        ? copy.t('Managed directly by TheRain', 'Géré directement par TheRain')
        : copy.t(
            'No fleet controls this account',
            'Aucun parc ne gère ce compte',
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                icon: isFleet
                    ? Icons.groups_outlined
                    : Icons.person_pin_circle_outlined,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.t('Driver relationship', 'Rattachement du chauffeur'),
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      affiliation.isEmpty
                          ? copy.t('Not selected', 'Non sélectionné')
                          : affiliation,
                    ),
                  ],
                ),
              ),
              if (isFleet)
                IconButton(
                  tooltip: copy.t(
                    'View fleet membership',
                    "Voir l'appartenance au parc",
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    RouteNames.membershipPending,
                  ),
                  icon: Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
          Divider(height: 24),
          Text(relationship),
          SizedBox(height: 8),
          Text(
            copy.t(
              'Fleet membership and driver verification are reviewed separately. A fleet cannot approve your identity documents.',
              "L'appartenance à un parc et la vérification du chauffeur sont "
                  "examinées séparément. Un parc ne peut pas approuver vos "
                  "documents d'identité.",
            ),
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(
    DriverCopy copy,
    DriverVerification? verification, {
    required bool needsResubmission,
  }) {
    final reason = verification?.rejectionReason;
    return AppCard(
      color: needsResubmission
          ? AppColors.dangerSoftFor(context)
          : AppColors.surfaceFor(context),
      borderColor: needsResubmission
          ? AppColors.danger
          : AppColors.borderFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t(
              'Documents tied to this driver',
              'Documents liés à ce chauffeur',
            ),
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          _documentRow(
            copy,
            copy.t('National ID', "Carte d'identité nationale"),
            verification?.nationalIdPath,
            verification?.status,
          ),
          SizedBox(height: 10),
          _documentRow(
            copy,
            copy.t("Driver's licence", 'Permis de conduire'),
            verification?.licencePath,
            verification?.status,
          ),
          SizedBox(height: 10),
          _documentRow(
            copy,
            copy.t('Live selfie', 'Selfie en direct'),
            verification?.selfiePath,
            verification?.status,
          ),
          if (reason != null && reason.trim().isNotEmpty) ...[
            Divider(height: 24),
            Text(
              '${copy.t('Review feedback', "Commentaire de l'examen")}: $reason',
            ),
          ],
        ],
      ),
    );
  }

  Widget _documentRow(
    DriverCopy copy,
    String label,
    String? path,
    DriverVerificationStatus? status,
  ) {
    final attached = path != null && path.trim().isNotEmpty;
    final text = !attached
        ? copy.t('Missing', 'Manquant')
        : switch (status) {
            DriverVerificationStatus.approved => copy.t('Verified', 'Vérifié'),
            DriverVerificationStatus.rejected ||
            DriverVerificationStatus.resubmissionRequired => copy.t(
              'Needs review',
              'À réexaminer',
            ),
            DriverVerificationStatus.pending => copy.t(
              'In review',
              "En cours d'examen",
            ),
            _ => copy.t('Attached', 'Joint'),
          };
    final color = !attached
        ? AppColors.danger
        : status == DriverVerificationStatus.approved
        ? AppColors.success
        : status == DriverVerificationStatus.rejected ||
              status == DriverVerificationStatus.resubmissionRequired
        ? AppColors.danger
        : AppColors.warning;
    return Row(
      children: [
        Icon(
          attached ? Icons.description_outlined : Icons.error_outline_rounded,
          color: color,
          size: 20,
        ),
        SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
