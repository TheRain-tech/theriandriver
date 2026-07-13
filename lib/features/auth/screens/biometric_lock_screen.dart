import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/biometric_service.dart';
import '../../../theme/app_colors.dart';

/// Shown at cold start instead of going straight to the dashboard, only when
/// the current device already has an active Firebase session AND biometrics
/// was previously enabled for that same uid on this device. Gates re-entry
/// to the already-persisted session — it never replaces the original
/// email/password (or Google) login. Failure always falls back to a normal
/// password login (never a permanent lockout).
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _isChecking = false;
  bool _isFallingBack = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _error = null;
    });
    final success = await BiometricService.instance.authenticate(
      reason: 'Unlock TheRain Driver',
    );
    if (!mounted) return;
    if (success) {
      await _continueToApp();
    } else {
      setState(() {
        _isChecking = false;
        _error = 'Biometric verification failed or was cancelled.';
      });
    }
  }

  Future<void> _continueToApp() async {
    try {
      final route = await AuthService.instance.landingRouteForCurrentUser();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _error = AuthService.instance.friendlyError(error);
      });
    }
  }

  Future<void> _usePasswordInstead() async {
    if (_isFallingBack) return;
    setState(() => _isFallingBack = true);
    // Never a permanent lockout: sign out of the persisted session and drop
    // back to the normal email/password login screen.
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, RouteNames.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(),
              const SizedBox(height: 40),
              Container(
                height: 140,
                width: 140,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your fingerprint or face to unlock TheRain Driver.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Unlock with Biometrics',
                icon: Icons.fingerprint_rounded,
                isLoading: _isChecking,
                onPressed: _tryUnlock,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isFallingBack ? null : _usePasswordInstead,
                child: const Text('Use Password Instead'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
