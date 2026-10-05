import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/password_policy.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';

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
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Accept the driver terms before continuing.',
              'Acceptez les conditions du chauffeur avant de continuer.',
            ),
          ),
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
        email: _email.text.trim().toLowerCase(),
        password: _password.text.trim(),
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
                Center(child: AppLogo(compact: true)),
                SizedBox(height: 22),
                Text(
                  DriverCopy.of(context).t('ACCOUNT 1 OF 4', 'COMPTE 1 SUR 4'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  DriverCopy.of(
                    context,
                  ).t('Create your driver account', 'Créez votre compte chauffeur'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 6),
                Text(
                  DriverCopy.of(context).t(
                    'Your account is created now. Vehicle and document setup can be resumed later.',
                    'Votre compte est créé maintenant. La configuration du véhicule et des documents peut être reprise plus tard.',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28),
                TextFormField(
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => Validators.required(
                    value,
                    DriverCopy.of(context).t('Full name', 'Nom complet'),
                  ),
                  decoration: InputDecoration(
                    labelText: DriverCopy.of(
                      context,
                    ).t('Full Name', 'Nom complet'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: Validators.phone,
                  decoration: InputDecoration(
                    labelText: DriverCopy.of(
                      context,
                    ).t('Phone Number', 'Numéro de téléphone'),
                    prefixText: '+237  ',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  decoration: InputDecoration(
                    labelText: DriverCopy.of(
                      context,
                    ).t('Email Address', 'Adresse e-mail'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _region,
                  items: DriverTaxonomy.regions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option.value,
                          child: Text(
                            option.localizedLabel(
                              DriverCopy.of(context).isFrench,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _region = value),
                  validator: (value) => value == null
                      ? DriverCopy.of(
                          context,
                        ).t('Select your region', 'Sélectionnez votre région')
                      : null,
                  decoration: InputDecoration(
                    labelText: DriverCopy.of(context).t('Region', 'Région'),
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      validatePasswordStrength(value, DriverCopy.of(context)),
                  onFieldSubmitted: (_) => _continueToDriverDetails(),
                  decoration: InputDecoration(
                    labelText: DriverCopy.of(
                      context,
                    ).t('Password', 'Mot de passe'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: DriverCopy.of(context).t(
                        _showPassword ? 'Hide password' : 'Show password',
                        _showPassword
                            ? 'Masquer le mot de passe'
                            : 'Afficher le mot de passe',
                      ),
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
                SizedBox(height: 12),
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _acceptedTerms = value ?? false);
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DriverCopy.of(
                      context,
                    ).t('I accept TheRain driver terms', "J'accepte les conditions chauffeur de TheRain"),
                  ),
                  subtitle: Text(
                    DriverCopy.of(context).t(
                      'TheRain must verify your identity, licence, vehicle, and fleet relationship before you can go online.',
                      'TheRain doit vérifier votre identité, votre permis, votre véhicule et votre relation avec une flotte avant que vous puissiez passer en ligne.',
                    ),
                  ),
                ),
                SizedBox(height: 22),
                PrimaryButton(
                  label: DriverCopy.of(
                    context,
                  ).t('Create account', 'Créer le compte'),
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _continueToDriverDetails,
                ),
                SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pushReplacementNamed(
                          context,
                          RouteNames.login,
                        ),
                  child: Text(
                    DriverCopy.of(
                      context,
                    ).t('Already registered? Log in', 'Déjà inscrit ? Se connecter'),
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
