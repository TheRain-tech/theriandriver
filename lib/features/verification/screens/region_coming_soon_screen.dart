import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/driver_status_strings.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../shared/widgets/feature_templates.dart';

class RegionComingSoonScreen extends StatefulWidget {
  const RegionComingSoonScreen({super.key});

  @override
  State<RegionComingSoonScreen> createState() => _RegionComingSoonScreenState();
}

class _RegionComingSoonScreenState extends State<RegionComingSoonScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(announce: false),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refresh(announce: false),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(announce: false);
  }

  Future<void> _refresh({required bool announce}) async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final uid = AuthService.instance.currentUserId;
      if (uid == null) return;
      final route = await AuthService.instance.landingRouteForUser(uid);
      if (!mounted) return;
      if (route != RouteNames.comingSoon) {
        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
        return;
      }
      if (announce) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStatusStrings.of(context).stillWaiting)),
        );
      }
    } catch (error) {
      if (announce && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.instance.friendlyError(error))),
        );
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = DriverStatusStrings.of(context);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Theme(
      data: dark ? AppTheme.dark : AppTheme.light,
      child: Builder(
        builder: (context) => Scaffold(
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
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      size: 96,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    strings.comingSoonTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.comingSoonIntro,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Text(
                      strings.comingSoonDetails,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: strings.viewApplicationStatus,
                    icon: Icons.refresh_rounded,
                    onPressed: () => _refresh(announce: true),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      RouteNames.contactSupport,
                    ),
                    icon: const Icon(Icons.headset_mic_outlined),
                    label: Text(strings.contactSupport),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    DriverProfileService.instance.profile.value.regionId ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
