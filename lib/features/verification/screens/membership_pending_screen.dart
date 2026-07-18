import 'package:flutter/material.dart';

import '../../../data/repositories/fleet_membership_repository.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';

/// Phase 5: standalone Fleet membership status viewer, reachable any time (not only during
/// onboarding) - e.g. after a Fleet invites an already-approved independent driver, or while a
/// join request awaits the Fleet's response. Always re-fetches from node-api rather than trusting
/// any locally cached status - membership status is never client-controlled.
class MembershipPendingScreen extends StatefulWidget {
  const MembershipPendingScreen({
    super.key,
    FleetMembershipRepository? repository,
  }) : _repository = repository;

  final FleetMembershipRepository? _repository;

  @override
  State<MembershipPendingScreen> createState() =>
      _MembershipPendingScreenState();
}

class _MembershipPendingScreenState extends State<MembershipPendingScreen> {
  late final FleetMembershipRepository _repository =
      widget._repository ?? FleetMembershipRepository();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _membership;
  String? _error;

  static const _statusLabels = <String, String>{
    'invited': 'Invitation received',
    'pending': 'Awaiting TheRain approval',
    'active': 'Active',
    'suspended': 'Suspended',
  };

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
        _error = error is ApiException
            ? error.message
            : 'Could not load your Fleet membership status.';
      });
    }
  }

  Future<void> _respond(bool accept) async {
    final membershipId = _membership?['id']?.toString();
    if (membershipId == null) return;
    setState(() => _isSubmitting = true);
    try {
      if (accept) {
        await _repository.acceptInvitation(membershipId);
      } else {
        await _repository.declineInvitation(membershipId);
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = error is ApiException
            ? error.message
            : 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DriverAppBar(showBack: true, title: 'Fleet Membership'),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_membership == null)
                  const AppCard(
                    child: Row(
                      children: [
                        IconWell(icon: Icons.groups_outlined),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'You do not currently have a Fleet membership.',
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabels[_membership!['status']] ??
                              _membership!['status'].toString(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fleet ID: ${_membership!['fleetId']}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (_membership!['status'] == 'invited') ...[
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Accept Invitation',
                      isLoading: _isSubmitting,
                      onPressed: () => _respond(true),
                    ),
                    const SizedBox(height: 10),
                    AppOutlineButton(
                      label: 'Decline',
                      onPressed: _isSubmitting ? null : () => _respond(false),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
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
