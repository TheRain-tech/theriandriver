import 'dart:async';

import 'package:flutter/material.dart';

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
                    ? 'Documents Need Attention'
                    : 'Verification Pending',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: 12),
              Text(
                needsResubmission
                    ? 'Review the feedback below, update your documents, and '
                          'submit them again.'
                    : 'Your documents were submitted successfully. This page '
                          'updates automatically when an administrator reviews '
                          'your account.',
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
                          Text('Status'),
                          SizedBox(height: 3),
                          Text(
                            _statusLabel(status, _profile?.lifecycleStatus),
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
                      label: needsResubmission ? 'Action Needed' : 'In Review',
                      tone: needsResubmission
                          ? BadgeTone.danger
                          : BadgeTone.warning,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              _buildRelationshipCard(),
              if (uid != null) ...[
                SizedBox(height: 14),
                StreamBuilder<DriverVerification?>(
                  stream: _verificationRepository.watchVerification(uid),
                  builder: (context, snapshot) {
                    return _buildDocumentsCard(
                      snapshot.data,
                      needsResubmission: needsResubmission,
                    );
                  },
                ),
              ],
              if (_streamError != null) ...[
                SizedBox(height: 14),
                Text(
                  'The live review status is temporarily unavailable. '
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
              SizedBox(height: 22),
              PrimaryButton(
                label: needsResubmission
                    ? 'Update Verification Documents'
                    : 'Awaiting Administrator Review',
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
                'Ride access remains disabled until administrator approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.contactSupport),
                icon: Icon(Icons.chat_bubble_outline_rounded),
                label: Text('Contact Support'),
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
                label: Text('Sign Out of Account'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(
    DriverVerificationStatus status,
    String? lifecycleStatus,
  ) {
    final lifecycle = lifecycleStatus?.toUpperCase();
    if (lifecycle == 'APPOINTMENT_SCHEDULED') return 'Appointment Scheduled';
    if (lifecycle == 'APPOINTMENT_COMPLETED') {
      return 'Appointment Completed';
    }
    if (lifecycle == 'UNDER_VERIFICATION') return 'Under Verification';
    if (lifecycle == 'REJECTED') return 'Rejected';
    if (lifecycle == 'APPROVED' || lifecycle == 'ACTIVE') return 'Approved';

    return switch (status) {
      DriverVerificationStatus.rejected => 'Rejected',
      DriverVerificationStatus.resubmissionRequired => 'Resubmission Required',
      DriverVerificationStatus.approved => 'Approved',
      _ => 'Pending Review',
    };
  }

  Widget _buildRelationshipCard() {
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
                  ? 'Fleet link awaiting confirmation'
                  : 'Fleet $fleetId')
        : profile?.affiliationType == 'therain_managed'
        ? 'Managed directly by TheRain'
        : 'No fleet controls this account';

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
                      'Driver relationship',
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(affiliation.isEmpty ? 'Not selected' : affiliation),
                  ],
                ),
              ),
              if (isFleet)
                IconButton(
                  tooltip: 'View fleet membership',
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
            'Fleet membership and driver verification are reviewed separately. A fleet cannot approve your identity documents.',
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
            'Documents tied to this driver',
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          _documentRow(
            'National ID',
            verification?.nationalIdPath,
            verification?.status,
          ),
          SizedBox(height: 10),
          _documentRow(
            "Driver's licence",
            verification?.licencePath,
            verification?.status,
          ),
          SizedBox(height: 10),
          _documentRow(
            'Live selfie',
            verification?.selfiePath,
            verification?.status,
          ),
          if (reason != null && reason.trim().isNotEmpty) ...[
            Divider(height: 24),
            Text('Review feedback: $reason'),
          ],
        ],
      ),
    );
  }

  Widget _documentRow(
    String label,
    String? path,
    DriverVerificationStatus? status,
  ) {
    final attached = path != null && path.trim().isNotEmpty;
    final text = !attached
        ? 'Missing'
        : switch (status) {
            DriverVerificationStatus.approved => 'Verified',
            DriverVerificationStatus.rejected ||
            DriverVerificationStatus.resubmissionRequired => 'Needs review',
            DriverVerificationStatus.pending => 'In review',
            _ => 'Attached',
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
