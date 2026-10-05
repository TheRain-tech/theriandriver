import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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

  String _statusLabel(String? status, DriverCopy l) {
    return switch (status) {
      'invited' => l.t('Invitation received', 'Invitation reçue'),
      'pending' => l.t(
        'Awaiting TheRain approval',
        'En attente d\'approbation de TheRain',
      ),
      'active' => l.t('Active', 'Actif'),
      'suspended' => l.t('Suspended', 'Suspendu'),
      _ => status ?? '',
    };
  }

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
            : DriverCopy.current.t(
                'Could not load your Fleet membership status.',
                'Impossible de charger le statut de votre adhésion à la flotte.',
              );
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
            : DriverCopy.current.t(
                'Something went wrong. Please try again.',
                'Une erreur s\'est produite. Veuillez réessayer.',
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
      appBar: DriverAppBar(
        showBack: true,
        title: l.t('Fleet Membership', 'Adhésion à la flotte'),
      ),
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
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_membership == null)
                  AppCard(
                    child: Row(
                      children: [
                        IconWell(icon: Icons.groups_outlined),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l.t(
                              'You do not currently have a Fleet membership.',
                              'Vous n\'avez actuellement aucune adhésion à une flotte.',
                            ),
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
                          _statusLabel(
                            _membership!['status']?.toString(),
                            l,
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 6),
                        Text(
                          (_membership!['fleetName'] as String?)?.trim().isNotEmpty ==
                                  true
                              ? _membership!['fleetName'] as String
                              : l.t('Fleet membership', 'Adhésion à la flotte'),
                          style: TextStyle(
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_membership!['status'] == 'invited') ...[
                    SizedBox(height: 16),
                    PrimaryButton(
                      label: l.t('Accept Invitation', 'Accepter l\'invitation'),
                      isLoading: _isSubmitting,
                      onPressed: () => _respond(true),
                    ),
                    SizedBox(height: 10),
                    AppOutlineButton(
                      label: l.t('Decline', 'Refuser'),
                      onPressed: _isSubmitting ? null : () => _respond(false),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.red, fontSize: 13),
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
