import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
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
    if (profile.verificationStatus == DriverVerificationStatus.approved) {
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
              const Center(child: AppLogo(compact: true)),
              const SizedBox(height: 34),
              Container(
                height: 230,
                decoration: BoxDecoration(
                  color: needsResubmission
                      ? AppColors.dangerSoft
                      : AppColors.primarySoft,
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
              const SizedBox(height: 30),
              Text(
                needsResubmission
                    ? 'Documents Need Attention'
                    : 'Verification Pending',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                needsResubmission
                    ? 'Review the feedback below, update your documents, and '
                          'submit them again.'
                    : 'Your documents were submitted successfully. This page '
                          'updates automatically when an administrator reviews '
                          'your account.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Row(
                  children: [
                    IconWell(
                      icon: needsResubmission
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status'),
                          const SizedBox(height: 3),
                          Text(
                            _statusLabel(status),
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
              if (uid != null && needsResubmission) ...[
                const SizedBox(height: 14),
                StreamBuilder<DriverVerification?>(
                  stream: _verificationRepository.watchVerification(uid),
                  builder: (context, snapshot) {
                    final reason = snapshot.data?.rejectionReason;
                    if (reason == null || reason.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return AppCard(
                      color: AppColors.dangerSoft,
                      child: Text('Review feedback: $reason'),
                    );
                  },
                ),
              ],
              if (_streamError != null) ...[
                const SizedBox(height: 14),
                const Text(
                  'The live review status is temporarily unavailable. '
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryButton(
                label: needsResubmission
                    ? 'Update Verification Documents'
                    : 'Awaiting Administrator Review',
                onPressed: needsResubmission
                    ? () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.profileSetup,
                        (route) => false,
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ride access remains disabled until administrator approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.contactSupport),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Contact Support'),
              ),
              const SizedBox(height: 8),
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
                    : const Icon(Icons.logout_rounded),
                label: const Text('Sign Out of Account'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(DriverVerificationStatus status) {
    return switch (status) {
      DriverVerificationStatus.rejected => 'Rejected',
      DriverVerificationStatus.resubmissionRequired => 'Resubmission Required',
      DriverVerificationStatus.approved => 'Approved',
      _ => 'Pending Review',
    };
  }
}
