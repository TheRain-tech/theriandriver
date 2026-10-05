import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/biometric_service.dart';
import '../../../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final route = await AuthService.instance.signIn(
        email: _email.text.trim().toLowerCase(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      await _afterSuccessfulLogin(route);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.friendlyError(error))),
      );
      setState(() => _isSubmitting = false);
    }
  }

  /// First successful login on a device that supports biometrics and
  /// doesn't have it enabled yet for this uid: prompt to enable, following
  /// the standard pattern (enable now -> confirm with one real biometric
  /// scan -> store only an opaque per-device/per-uid flag, never the
  /// password). Declining or an unsupported device just proceeds straight
  /// into the app — this is never a blocking step.
  Future<void> _afterSuccessfulLogin(String route) async {
    final uid = AuthService.instance.currentUserId;
    if (uid != null && await BiometricService.instance.isDeviceSupported) {
      final alreadyEnabled = await BiometricService.instance.isEnabledForUid(
        uid,
      );
      if (!alreadyEnabled && mounted) {
        final wantsToEnable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              DriverCopy.current.t(
                'Enable biometric login?',
                'Activer la connexion biométrique ?',
              ),
            ),
            content: Text(
              DriverCopy.current.t(
                'Use your fingerprint or face to unlock TheRain Driver next '
                    'time, instead of typing your password.',
                'Utilisez votre empreinte ou votre visage pour déverrouiller TheRain Driver la prochaine fois, au lieu de saisir votre mot de passe.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(DriverCopy.current.t('Not now', 'Pas maintenant')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(DriverCopy.current.t('Enable', 'Activer')),
              ),
            ],
          ),
        );
        if (wantsToEnable == true) {
          final confirmed = await BiometricService.instance.authenticate(
            reason: 'Confirm to enable biometric login',
          );
          if (confirmed) await BiometricService.instance.setEnabled(uid, true);
        }
      }
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    final validation = Validators.email(email);
    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    try {
      await AuthService.instance.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Password reset email sent. Check your inbox.',
              'E-mail de réinitialisation du mot de passe envoyé. Vérifiez votre boîte de réception.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 34),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                const Center(child: AppLogo(compact: true)),
                const SizedBox(height: 28),
                Text.rich(
                  TextSpan(
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.textPrimaryFor(context),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: DriverCopy.of(context).t('Welcome ', 'Bon '),
                      ),
                      TextSpan(
                        text: DriverCopy.of(context).t('Back!', 'retour !'),
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DriverCopy.of(context).t(
                    'Log in to continue your journey\nwith TheRain.',
                    'Connectez-vous pour continuer votre parcours\navec TheRain.',
                  ),
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondaryFor(context),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: DriverCopy.of(
                      context,
                    ).t('Email Address', 'Adresse e-mail'),
                    prefixIcon: const _LoginFieldIcon(icon: Icons.mail_outline),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 70,
                      minHeight: 60,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide(color: AppColors.borderFor(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  validator: (value) => Validators.required(
                    value,
                    DriverCopy.of(context).t('Password', 'Mot de passe'),
                  ),
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: DriverCopy.of(
                      context,
                    ).t('Password', 'Mot de passe'),
                    prefixIcon: const _LoginFieldIcon(
                      icon: Icons.lock_outline_rounded,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 70,
                      minHeight: 60,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide(color: AppColors.borderFor(context)),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _resetPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      DriverCopy.of(
                        context,
                      ).t('Forgot password?', 'Mot de passe oublié ?'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: DriverCopy.of(context).t('Login', 'Connexion'),
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _login,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        RouteNames.signup,
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryFor(context),
                          ),
                          children: [
                            TextSpan(
                              text: DriverCopy.of(context).t(
                                "Don't have an account? ",
                                "Pas encore de compte ? ",
                              ),
                            ),
                            TextSpan(
                              text: DriverCopy.of(
                                context,
                              ).t('Sign up', "S'inscrire"),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _isSubmitting
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            RouteNames.claimInvitation,
                          ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _LoginFieldIcon(
                            icon: Icons.verified_user_outlined,
                            compact: true,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              DriverCopy.of(context).t(
                                'Have an invitation code from a fleet?',
                                "Vous avez un code d'invitation d'une flotte ?",
                              ),
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFieldIcon extends StatelessWidget {
  const _LoginFieldIcon({required this.icon, this.compact = false});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 48 : 50,
    height: compact ? 48 : 50,
    margin: EdgeInsets.only(left: compact ? 0 : 8),
    decoration: BoxDecoration(
      color: AppColors.primarySoftFor(context),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(
      icon,
      color: AppColors.textPrimaryFor(context),
      size: compact ? 24 : 26,
    ),
  );
}
