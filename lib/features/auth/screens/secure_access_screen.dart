import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../services/app_lock_service.dart';
import '../../../theme/app_colors.dart';

/// A local re-entry gate on top of the driver's existing Firebase Auth session - never a second
/// identity authority, and never shown at all when the device has no PIN/pattern/password/
/// fingerprint/face unlock configured (see _checkAndUnlock): a device with nothing to gate with
/// goes straight through to the account, matching how the app behaved before this screen existed.
class SecureAccessScreen extends StatefulWidget {
  const SecureAccessScreen({super.key});

  @override
  State<SecureAccessScreen> createState() => _SecureAccessScreenState();
}

class _SecureAccessScreenState extends State<SecureAccessScreen> {
  bool _checking = true;
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
    // A driver whose phone has no PIN/pattern/password/fingerprint/face unlock set up at all
    // can never satisfy this gate - local_auth has nothing to prompt. There is no account-level
    // credential being skipped here (Firebase Auth's own session is unaffected either way) - this
    // screen is only a local convenience gate on top of that session, so a device with no lock
    // capability simply has nothing to gate with.
    if (!canAuthenticate) {
      AppLockService.instance.markUnlockedSession();
      _continue();
      return;
    }
    setState(() => _checking = false);
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
      _message = DriverCopy.current.t(
        'Account access was not unlocked. Try again to continue.',
        "L'accès au compte n'a pas été déverrouillé. Réessayez pour continuer.",
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppLogo(compact: true)),
              const Spacer(),
              Icon(
                Icons.lock_person_rounded,
                size: 92,
                color: AppColors.primary,
              ),
              SizedBox(height: 24),
              Text(
                DriverCopy.of(context).t('Unlock Driver Account', 'Déverrouiller le compte chauffeur'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 12),
              Text(
                DriverCopy.of(context).t(
                  'Use your phone PIN, password, fingerprint, or face unlock.',
                  'Utilisez le code PIN, le mot de passe, l\'empreinte ou le déverrouillage facial de votre téléphone.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.45),
              ),
              if (_message != null) ...[
                SizedBox(height: 14),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
              SizedBox(height: 28),
              if (_checking)
                Center(child: CircularProgressIndicator())
              else
                PrimaryButton(
                  label: DriverCopy.of(context).t('Unlock', 'Déverrouiller'),
                  icon: Icons.lock_open_rounded,
                  isLoading: _authenticating,
                  onPressed: _authenticate,
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
