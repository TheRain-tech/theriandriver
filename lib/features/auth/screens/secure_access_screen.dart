import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../services/app_lock_service.dart';
import '../../../theme/app_colors.dart';

class SecureAccessScreen extends StatefulWidget {
  const SecureAccessScreen({super.key});

  @override
  State<SecureAccessScreen> createState() => _SecureAccessScreenState();
}

class _SecureAccessScreenState extends State<SecureAccessScreen> {
  bool _checking = true;
  bool _deviceSecure = true;
  bool _authenticating = false;
  String? _message;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _checkAndUnlock();
  }

  Future<void> _checkAndUnlock() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    final canAuthenticate = await AppLockService.instance.canAuthenticate();
    if (!mounted) return;
    if (!canAuthenticate) {
      setState(() {
        _checking = false;
        _deviceSecure = false;
      });
      return;
    }
    setState(() {
      _checking = false;
      _deviceSecure = true;
    });
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final ok = await AppLockService.instance.authenticateForAccountAccess();
    if (!mounted) return;
    if (ok) {
      _continue();
      return;
    }
    setState(() {
      _authenticating = false;
      _message = 'Account access was not unlocked. Try again to continue.';
    });
  }

  void _continue() {
    final argument = ModalRoute.of(context)?.settings.arguments;
    final destination = argument is String
        ? argument
        : AppLockService.instance.consumePendingRoute(
            fallback: RouteNames.dashboard,
          );
    Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
  }

  Future<void> _openSettings() async {
    await AppLockService.instance.openSecuritySettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(compact: true)),
              const Spacer(),
              Icon(
                _deviceSecure
                    ? Icons.lock_person_rounded
                    : Icons.phonelink_lock_outlined,
                size: 92,
                color: _deviceSecure ? AppColors.primary : AppColors.danger,
              ),
              const SizedBox(height: 24),
              Text(
                _deviceSecure ? 'Unlock Driver Account' : 'Secure Lock Needed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                _deviceSecure
                    ? 'Use your phone PIN, password, fingerprint, or face unlock.'
                    : 'For driver account safety, please set up a phone screen lock, fingerprint, or face unlock in your device settings.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.45),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 28),
              if (_checking)
                const Center(child: CircularProgressIndicator())
              else if (_deviceSecure)
                PrimaryButton(
                  label: 'Unlock',
                  icon: Icons.lock_open_rounded,
                  isLoading: _authenticating,
                  onPressed: _authenticate,
                )
              else ...[
                PrimaryButton(
                  label: 'Open Security Settings',
                  icon: Icons.settings_outlined,
                  onPressed: _openSettings,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _checkAndUnlock,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check Again'),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
