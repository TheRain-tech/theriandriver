import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../config/firebase_config.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/biometric_service.dart';
import '../../../theme/app_colors.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    try {
      if (!FirebaseConfig.isAvailable) {
        await FirebaseConfig.initialize();
        if (!FirebaseConfig.isAvailable) {
          final error = FirebaseConfig.initializationError;
          throw StateError(
            error == null
                ? 'TheRain Driver could not connect to Firebase. Check your '
                      'connection and try again.'
                : 'TheRain Driver could not start securely. Check your '
                      'connection and Firebase configuration, then try again.',
          );
        }
      }
      // Biometric re-entry gate: only offered when this device already has
      // an active Firebase session AND biometrics was previously enabled
      // for that exact uid on this exact device (never transfers devices —
      // see BiometricService).
      final uid = AuthService.instance.currentUserId;
      if (uid != null) {
        final biometricEnabled = await BiometricService.instance
            .isEnabledForUid(uid);
        if (biometricEnabled && await BiometricService.instance.isDeviceSupported) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.biometricLock,
            (_) => false,
          );
          return;
        }
      }
      final route = await AuthService.instance.landingRouteForCurrentUser();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthService.instance.friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(),
                const SizedBox(height: 24),
                if (_error == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  const Text('Preparing your driver account...'),
                ] else ...[
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _error = null);
                      _resolveSession();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
