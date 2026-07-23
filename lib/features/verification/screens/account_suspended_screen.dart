import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/localization/driver_status_strings.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_appeal.dart';
import '../../../data/repositories/fleet_relations_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// Shown instead of the normal Dashboard for the entire time a driver's
/// account is SUSPENDED (node-api's driver.service.js#suspend). No other
/// page is reachable from here except Appeal, Support, Logout, Privacy
/// Policy, and Terms — the router guard (app_routes.dart) forces every other
/// protected route back to this screen for as long as
/// DriverProfile.isSuspended is true.
class AccountSuspendedScreen extends StatefulWidget {
  const AccountSuspendedScreen({super.key});

  @override
  State<AccountSuspendedScreen> createState() => _AccountSuspendedScreenState();
}

class _AccountSuspendedScreenState extends State<AccountSuspendedScreen> {
  final _repository = FleetRelationsRepository();
  bool _isSigningOut = false;
  Future<DriverAppeal?>? _appealFuture;

  @override
  void initState() {
    super.initState();
    DriverProfileService.instance.bindAuthenticatedDriver();
    final uid = AuthService.instance.currentUserId;
    if (uid != null) {
      _appealFuture = _repository.getLatestAppeal(uid).catchError((_) => null);
    }
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
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.instance.friendlyError(error))),
        );
      }
    }
  }

  Future<void> _submitAppeal() async {
    final submitted = await Navigator.pushNamed(
      context,
      RouteNames.submitAppeal,
    );
    if (submitted == true && mounted) {
      final uid = AuthService.instance.currentUserId;
      setState(() {
        _appealFuture = uid == null
            ? null
            : _repository.getLatestAppeal(uid).catchError((_) => null);
      });
    }
  }

  Future<void> _contactFleetManager() async {
    final fleetInfo = DriverProfileService.instance.fleetInfo.value;
    final phone = fleetInfo?.phoneNumber;
    final email = fleetInfo?.email;
    Uri? uri;
    if (phone != null && phone.trim().isNotEmpty) {
      uri = Uri(scheme: 'tel', path: phone.trim());
    } else if (email != null && email.trim().isNotEmpty) {
      uri = Uri(scheme: 'mailto', path: email.trim());
    }
    if (uri == null || !await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fleet contact details are available yet.'),
        ),
      );
    }
  }

  void _showPolicyDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = DriverProfileService.instance.profile.value;
    final strings = DriverStatusStrings.of(context);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final suspension = profile.suspension;
    final isFleetDriver = profile.isFleetDriver;
    final fleetInfo = DriverProfileService.instance.fleetInfo.value;
    final inheritedFleetSuspension =
        fleetInfo?.isSuspended == true && !profile.isSuspended;
    final fleetSuspension = fleetInfo?.suspension ?? const <String, dynamic>{};
    final fleetSuspensionDate = DateTime.tryParse(
      (fleetSuspension['date'] ?? fleetSuspension['suspendedAt'] ?? '')
          .toString(),
    );
    final suspensionId = inheritedFleetSuspension
        ? (fleetSuspension['id'] ?? '—').toString()
        : suspension?.id ?? '—';
    final suspensionReason = inheritedFleetSuspension
        ? (fleetSuspension['reason'] ?? 'Under review').toString()
        : suspension?.reasonLabel ?? 'Under review';
    final suspensionDate = inheritedFleetSuspension
        ? fleetSuspensionDate
        : suspension?.suspensionDate;
    final reviewStatus = inheritedFleetSuspension
        ? (fleetSuspension['reviewStatus'] ?? 'UNDER REVIEW').toString()
        : 'UNDER REVIEW';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF07111F) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(compact: true)),
              const SizedBox(height: 40),
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  color: AppColors.dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_flipped,
                  size: 100,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                inheritedFleetSuspension
                    ? strings.fleetSuspendedTitle
                    : strings.accountSuspendedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: dark ? Colors.white : AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                inheritedFleetSuspension
                    ? strings.fleetSuspendedMessage
                    : strings.accountSuspendedMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: dark ? const Color(0xFFCBD5E1) : AppColors.slate,
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                color: AppColors.dangerSoft,
                borderColor: const Color(0xFFFFC5CB),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabeledValue(
                      label: strings.status,
                      icon: Icons.block_rounded,
                      value: strings.suspended,
                    ),
                    const SizedBox(height: 14),
                    LabeledValue(
                      label: strings.suspensionId,
                      icon: Icons.tag_rounded,
                      value: suspensionId,
                    ),
                    const SizedBox(height: 14),
                    LabeledValue(
                      label: strings.suspensionDate,
                      icon: Icons.event_rounded,
                      value: suspensionDate == null
                          ? '—'
                          : DateFormatter.short(suspensionDate),
                    ),
                    const SizedBox(height: 14),
                    LabeledValue(
                      label: strings.suspensionReason,
                      icon: Icons.gavel_rounded,
                      value: suspensionReason,
                    ),
                    const SizedBox(height: 14),
                    LabeledValue(
                      label: strings.reviewStatus,
                      icon: Icons.manage_search_rounded,
                      value: reviewStatus,
                    ),
                    if (isFleetDriver) ...[
                      const SizedBox(height: 14),
                      LabeledValue(
                        label: 'Fleet',
                        icon: Icons.local_shipping_rounded,
                        value: fleetInfo?.fleetName ?? profile.fleetName ?? '—',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                inheritedFleetSuspension
                    ? strings.restoredAutomatically
                    : strings.accountSuspendedGuidance,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate, height: 1.5),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: strings.contactTheRainSupport,
                icon: Icons.headset_mic_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.contactSupport),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showPolicyDialog(
                  strings.suspensionDetailsTitle,
                  '${strings.suspensionId}: $suspensionId\n'
                  '${strings.suspensionDate}: ${suspensionDate == null ? '—' : DateFormatter.short(suspensionDate)}\n'
                  '${strings.suspensionReason}: $suspensionReason\n'
                  '${strings.reviewStatus}: $reviewStatus',
                ),
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(strings.viewSuspensionDetails),
              ),
              const SizedBox(height: 12),
              if (!inheritedFleetSuspension)
                FutureBuilder<DriverAppeal?>(
                  future: _appealFuture,
                  builder: (context, snapshot) {
                    final appeal = snapshot.data;
                    final hasOpenAppeal = appeal != null &&
                        appeal.status != 'REJECTED' &&
                        appeal.status != 'APPROVED';
                    if (hasOpenAppeal) {
                      return AppCard(
                        color: AppColors.primarySoft,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.hourglass_top_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Appeal status: ${appeal.displayStatus}',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return OutlinedButton.icon(
                      onPressed: _submitAppeal,
                      icon: const Icon(Icons.assignment_late_outlined),
                      label: const Text('Submit Appeal'),
                    );
                  },
                ),
              const SizedBox(height: 12),
              if (isFleetDriver)
                OutlinedButton.icon(
                  onPressed: _contactFleetManager,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: Text(strings.contactFleetManager),
                ),
              if (isFleetDriver) const SizedBox(height: 12),
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
              ),
              const SizedBox(height: 12),
              Text(
                inheritedFleetSuspension
                    ? strings.restoredAutomatically
                    : strings.accountSuspendedFooter,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _showPolicyDialog(
                      'Privacy Policy',
                      'TheRain protects your personal data and only shares '
                          'suspension details with authorized Regional and '
                          'Super Administrators for compliance review.',
                    ),
                    child: const Text('Privacy Policy'),
                  ),
                  TextButton(
                    onPressed: () => _showPolicyDialog(
                      'Terms of Service',
                      'Driving with TheRain is governed by the TheRain '
                          'Driver Terms of Service and Safety Policies, '
                          'which every driver agrees to at sign-up.',
                    ),
                    child: const Text('Terms of Service'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'TheRain Trust & Safety Center',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
