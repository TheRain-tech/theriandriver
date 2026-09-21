import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/fleet_membership_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// Entry point for a driver who received a one-time invitation from a Fleet Owner (Fleet app's
/// "Share Invitation" action). Tapping the shared link opens this screen with the code already filled in
/// and checked (see DeepLinkService); typing or pasting the code by hand works the same way. The driver only
/// ever provides the code and a password they choose - the inviting Fleet, region, and town are resolved
/// entirely server-side from the invitation (see FleetMembershipRepository.claimInvitation), never typed or
/// picked here. After a successful claim this reuses the app's normal sign-in flow
/// (AuthService.instance.signIn), so routing to the existing "pending regional approval" screen and the
/// Fleet Information card on the profile happen automatically through code that already exists.
class ClaimInvitationScreen extends StatefulWidget {
  const ClaimInvitationScreen({super.key});

  @override
  State<ClaimInvitationScreen> createState() => _ClaimInvitationScreenState();
}

class _ClaimInvitationScreenState extends State<ClaimInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _repository = FleetMembershipRepository();
  bool _isSubmitting = false;
  bool _isChecking = false;
  bool _openedFromLink = false;
  Map<String, dynamic>? _preview;
  String? _previewError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedFromLink) return;
    // Opened from a tapped invitation link: the code is already in the arguments - fill it in and check it
    // at once so the driver lands on "You're invited to join <fleet>" instead of an empty form.
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final token = arguments is Map
        ? arguments['token']?.toString()
        : arguments is String
        ? arguments
        : null;
    if (token == null || token.trim().isEmpty) return;
    _openedFromLink = true;
    _token.text = token.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkInvitation();
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _checkInvitation() async {
    final copy = DriverCopy.of(context);
    final token = _token.text.trim();
    if (token.length < 16) {
      setState(
        () => _previewError = copy.t(
          'Enter the invitation code exactly as shared with you',
          "Saisissez le code d'invitation exactement comme on vous l'a envoyé",
        ),
      );
      return;
    }
    setState(() {
      _isChecking = true;
      _previewError = null;
    });
    try {
      final preview = await _repository.previewInvitation(token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isChecking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _previewError = _friendlyError(error);
      });
    }
  }

  void _editCode() {
    setState(() {
      _preview = null;
      _previewError = null;
    });
  }

  Future<void> _submit() async {
    final copy = DriverCopy.of(context);
    if (_preview == null ||
        !_formKey.currentState!.validate() ||
        _isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await _repository.claimInvitation(
        token: _token.text.trim(),
        password: _password.text.trim(),
      );
      final driver = result['driver'];
      final email = driver is Map ? driver['email']?.toString() : null;
      if (email == null || email.trim().isEmpty) {
        throw Exception(
          copy.t(
            'Your account was created but could not be signed in automatically. Please log in.',
            'Votre compte a été créé mais la connexion automatique a échoué. Veuillez vous connecter.',
          ),
        );
      }
      final route = await AuthService.instance.signIn(
        email: email.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return AuthService.instance.friendlyError(error);
  }

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final fleetName = _preview?['fleetName']?.toString();
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
                SizedBox(height: 28),
                Text(
                  fleetName != null
                      ? copy.t(
                          "You're invited to join $fleetName",
                          'Vous êtes invité à rejoindre $fleetName',
                        )
                      : copy.t('Join Your Fleet', 'Rejoignez votre flotte'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 6),
                Text(
                  copy.t(
                    "Enter the invitation code your fleet sent you. We'll link your account to their fleet automatically.",
                    "Saisissez le code d'invitation envoyé par votre flotte. Nous rattacherons automatiquement votre compte à leur flotte.",
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28),
                TextFormField(
                  controller: _token,
                  readOnly: _preview != null,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) =>
                      (value == null || value.trim().length < 16)
                      ? copy.t(
                          'Enter the invitation code exactly as shared with you',
                          "Saisissez le code d'invitation exactement comme on vous l'a envoyé",
                        )
                      : null,
                  decoration: InputDecoration(
                    labelText: copy.t('Invitation Code', "Code d'invitation"),
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: _preview != null
                        ? IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: copy.t('Change code', 'Changer le code'),
                            onPressed: _isSubmitting ? null : _editCode,
                          )
                        : null,
                  ),
                ),
                if (_previewError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _previewError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                if (_preview == null) ...[
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: copy.t('Check Invitation', "Vérifier l'invitation"),
                    isLoading: _isChecking,
                    onPressed: _checkInvitation,
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  InvitationPreviewCard(preview: _preview!),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return copy.t(
                          'Password is required',
                          'Le mot de passe est obligatoire',
                        );
                      }
                      if (value.length < 8) {
                        return copy.t(
                          'Password must contain at least 8 characters',
                          'Le mot de passe doit contenir au moins 8 caractères',
                        );
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: copy.t(
                        'Choose a Password',
                        'Choisissez un mot de passe',
                      ),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) => value != _password.text
                        ? copy.t(
                            'Passwords do not match',
                            'Les mots de passe ne correspondent pas',
                          )
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: copy.t(
                        'Confirm Password',
                        'Confirmez le mot de passe',
                      ),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: copy.t('Join Fleet', 'Rejoindre la flotte'),
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pushReplacementNamed(
                          context,
                          RouteNames.login,
                        ),
                  child: Text(
                    copy.t(
                      'Already have an account? Log in',
                      'Vous avez déjà un compte ? Connectez-vous',
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

/// Shown once the code is verified against the backend (fleetMembership.service.js
/// #previewFleetInvitation) - the driver can see WHICH fleet is inviting them (name, logo, region), that the
/// invitation is still valid and until when, before choosing a password. Read-only preview only; the actual
/// account creation still happens in ClaimInvitationScreen._submit().
class InvitationPreviewCard extends StatelessWidget {
  const InvitationPreviewCard({required this.preview, super.key});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final fleetName = preview['fleetName']?.toString() ?? '';
    final displayName = fleetName.isEmpty
        ? copy.t('Your fleet', 'Votre flotte')
        : fleetName;
    final logoUrl = preview['fleetLogoUrl']?.toString();
    final region = (preview['regionName'] ?? preview['city'])?.toString();
    final expiresAt = DateTime.tryParse(preview['expiresAt']?.toString() ?? '');
    final status = preview['status']?.toString().toLowerCase() ?? 'invited';
    final statusLabel = status == 'invited'
        ? copy.t('Invitation valid', 'Invitation valide')
        : status;
    return AppCard(
      color: AppColors.primarySoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FleetAvatar(name: displayName, logoUrl: logoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t(
                    "You're joining $displayName",
                    'Vous rejoignez $displayName',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (region != null && region.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(region, style: const TextStyle(color: AppColors.slate)),
                ],
                const SizedBox(height: 6),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    copy.t(
                      'Code valid until ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                      "Code valable jusqu'au ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}",
                    ),
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The fleet's logo when it has one; otherwise its initial (a fleet without a logo is normal).
class _FleetAvatar extends StatelessWidget {
  const _FleetAvatar({required this.name, this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = logoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
