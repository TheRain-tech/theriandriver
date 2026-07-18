import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/fleet_membership_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/step_indicator.dart';

/// Phase 5 prompt section 21 ("Fleet Driver" onboarding sub-flow): shown only when the driver
/// selected affiliation "Fleet Driver". Never lets the driver type an arbitrary Fleet ID and have
/// it silently trusted - the "request to join" call always goes through node-api's
/// POST /api/drivers/me/membership/request, which validates the Fleet's existence, status, and
/// region match server-side before creating anything. If the driver already has a pending
/// invitation from a Fleet (created via the Fleet's own "Invite Driver" flow), that is shown here
/// directly instead, with Accept/Decline actions - never a code to type.
class FleetJoinScreen extends StatefulWidget {
  const FleetJoinScreen({super.key, FleetMembershipRepository? repository})
    : _repository = repository;

  final FleetMembershipRepository? _repository;

  @override
  State<FleetJoinScreen> createState() => _FleetJoinScreenState();
}

class _FleetJoinScreenState extends State<FleetJoinScreen> {
  late final FleetMembershipRepository _repository =
      widget._repository ?? FleetMembershipRepository();
  final _fleetCodeController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _membership;
  String? _error;
  String? _requestSentMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final membership = await _repository.getMyMembership();
      if (!mounted) return;
      setState(() {
        _membership = membership;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _accept(String membershipId) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _repository.acceptInvitation(membershipId);
      if (!mounted) return;
      _continue();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _decline(String membershipId) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _repository.declineInvitation(membershipId);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _membership = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _requestToJoin() async {
    final fleetId = _fleetCodeController.text.trim();
    if (fleetId.isEmpty) {
      setState(() => _error = 'Enter the Fleet code your Fleet gave you.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _repository.requestToJoin(fleetId);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _requestSentMessage =
            'Your request was sent. The Fleet will review it - you can continue setting up your account in the meantime.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _friendlyError(error);
      });
    }
  }

  void _continue() {
    Navigator.pushNamed(context, RouteNames.nationalId);
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _fleetCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepIndicator(current: 4, total: 4, labels: []),
              const SizedBox(height: 26),
              Text(
                'Join your Fleet',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'A TheRain admin must still approve your identity documents separately.',
              ),
              const SizedBox(height: 22),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_membership != null)
                _InvitationCard(
                  membership: _membership!,
                  isSubmitting: _isSubmitting,
                  onAccept: () => _accept(_membership!['id'].toString()),
                  onDecline: () => _decline(_membership!['id'].toString()),
                )
              else if (_requestSentMessage != null)
                AppCard(
                  color: AppColors.primarySoft,
                  child: Row(
                    children: [
                      const IconWell(icon: Icons.mark_email_read_outlined),
                      const SizedBox(width: 14),
                      Expanded(child: Text(_requestSentMessage!)),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Request to join a Fleet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the Fleet code your Fleet company gave you. They will review and approve your request.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _fleetCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Fleet code',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Send Request',
                  isLoading: _isSubmitting,
                  onPressed: _requestToJoin,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Continue',
                onPressed: _isSubmitting ? null : _continue,
              ),
              const SizedBox(height: 12),
              AppOutlineButton(
                label: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.membership,
    required this.isSubmitting,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> membership;
  final bool isSubmitting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final status = membership['status']?.toString() ?? '';
    if (status != 'invited') {
      return AppCard(
        child: Row(
          children: [
            const IconWell(icon: Icons.hourglass_top_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Your Fleet membership is $status. A TheRain admin will finish reviewing it.',
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              IconWell(icon: Icons.groups_outlined),
              SizedBox(width: 14),
              Expanded(child: Text('You have a Fleet invitation waiting.')),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Accept Invitation',
            isLoading: isSubmitting,
            onPressed: onAccept,
          ),
          const SizedBox(height: 10),
          AppOutlineButton(label: 'Decline', onPressed: onDecline),
        ],
      ),
    );
  }
}
