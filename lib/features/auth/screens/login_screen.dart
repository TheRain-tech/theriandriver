import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../config/env_config.dart';
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

  Future<void> _loginWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final route = await AuthService.instance.signInWithGoogle();
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
            title: const Text('Enable biometric login?'),
            content: const Text(
              'Use your fingerprint or face to unlock TheRain Driver next '
              'time, instead of typing your password.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enable'),
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
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
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
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo()),
                const SizedBox(height: 38),
                Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                const Text('Log in to continue', textAlign: TextAlign.center),
                const SizedBox(height: 34),
                TextFormField(
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  validator: (value) => Validators.required(value, 'Password'),
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Login',
                  isLoading: _isSubmitting,
                  onPressed: _login,
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _social(
                      Icons.g_mobiledata_rounded,
                      'Google',
                      EnvConfig.googleSignInEnabled ? _loginWithGoogle : null,
                    ),
                    const SizedBox(width: 10),
                    _social(Icons.apple_rounded, 'Apple', null),
                    const SizedBox(width: 10),
                    _social(Icons.facebook_rounded, 'Facebook', null),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    RouteNames.signup,
                  ),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _social(IconData icon, String label, VoidCallback? onPressed) =>
      Expanded(
        child: OutlinedButton(
          onPressed: _isSubmitting ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 27),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
}
