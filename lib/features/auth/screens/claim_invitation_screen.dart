import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/fleet_membership_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// Entry point for a driver who received a one-time invitation code from a Fleet Owner (Fleet
/// app's "Copy/Share Invitation" action). The driver only ever provides the code and a password
/// they choose - the inviting Fleet, region, and town are resolved entirely server-side from the
/// invitation (see FleetMembershipRepository.claimInvitation), never typed or picked here. After
/// a successful claim this reuses the app's normal sign-in flow (AuthService.instance.signIn),
/// so routing to the existing "pending regional approval" screen and the Fleet Information card
/// on the profile happen automatically through code that already exists - nothing new is built
/// for either of those.
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
  Map<String, dynamic>? _preview;
  String? _previewError;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _checkInvitation() async {
    final token = _token.text.trim();
    if (token.length < 16) {
      setState(
        () => _previewError =
            'Enter the invitation code exactly as shared with you',
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
    if (_preview == null || !_formKey.currentState!.validate() || _isSubmitting) {
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
          'Your account was created but could not be signed in automatically. Please log in.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return AuthService.instance.friendlyError(error);
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
                const SizedBox(height: 28),
                Text(
                  'Join Your Fleet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter the invitation code your fleet sent you. We\'ll link your account to their fleet automatically.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _token,
                  readOnly: _preview != null,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) => (value == null || value.trim().length < 16)
                      ? 'Enter the invitation code exactly as shared with you'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Invitation Code',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: _preview != null
                        ? IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Change code',
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
                    label: 'Check Invitation',
                    isLoading: _isChecking,
                    onPressed: _checkInvitation,
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  _InvitationPreviewCard(preview: _preview!),
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
                        return 'Password is required';
                      }
                      if (value.length < 8) {
                        return 'Password must contain at least 8 characters';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Choose a Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
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
                        ? 'Passwords do not match'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Join Fleet',
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
                  child: const Text('Already have an account? Log in'),
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
/// #previewFleetInvitation) - the driver can see WHICH fleet they're about to join, and that the
/// code is still valid, before choosing a password. Read-only preview only; the actual account
/// creation still happens in ClaimInvitationScreen._submit().
class _InvitationPreviewCard extends StatelessWidget {
  const _InvitationPreviewCard({required this.preview});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final fleetName = preview['fleetName']?.toString() ?? 'Your fleet';
    final city = preview['city']?.toString();
    final expiresAt = DateTime.tryParse(preview['expiresAt']?.toString() ?? '');
    return AppCard(
      color: AppColors.primarySoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconWell(icon: Icons.groups_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re joining $fleetName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (city != null && city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(city, style: const TextStyle(color: AppColors.slate)),
                ],
                if (expiresAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Code valid until ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
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
