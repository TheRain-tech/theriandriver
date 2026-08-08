import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_draft_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _region;
  bool _acceptedTerms = false;
  bool _isSubmitting = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continueToDriverDetails() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the driver terms before continuing.'),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final phoneNumber = _normalizePhone(_phone.text);
      RegistrationDraftService.instance.updateSignupCredentials(
        fullName: _fullName.text,
        phoneNumber: phoneNumber,
        email: _email.text,
        password: _password.text,
        acceptedTerms: _acceptedTerms,
      );
      final route = await AuthService.instance.signUp(
        fullName: _fullName.text,
        phoneNumber: phoneNumber,
        email: _email.text.trim().toLowerCase(),
        password: _password.text.trim(),
        cityRegion: _region!,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.friendlyError(error))),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _normalizePhone(String value) {
    final phone = value.trim();
    return phone.startsWith('+237') ? phone : '+237 $phone';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(compact: true)),
                const SizedBox(height: 22),
                const Text(
                  'ACCOUNT 1 OF 4',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0A84FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Create your driver account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your account is created now. Vehicle and document setup can be resumed later.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => Validators.required(value, 'Full name'),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: Validators.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+237  ',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _region,
                  items: DriverTaxonomy.regions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _region = value),
                  validator: (value) =>
                      value == null ? 'Select your region' : null,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    final required = Validators.required(value, 'Password');
                    if (required != null) return required;
                    if (value!.length < 6) {
                      return 'Password must contain at least 6 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _continueToDriverDetails(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _showPassword
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _acceptedTerms = value ?? false);
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I accept TheRain driver terms'),
                  subtitle: const Text(
                    'TheRain must verify your identity, licence, vehicle, and fleet relationship before you can go online.',
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Create account',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _continueToDriverDetails,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pushReplacementNamed(
                          context,
                          RouteNames.login,
                        ),
                  child: const Text('Already registered? Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
