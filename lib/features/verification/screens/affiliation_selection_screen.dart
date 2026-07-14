import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_taxonomy.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_sync_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/option_card.dart';
import '../../shared/widgets/step_indicator.dart';

/// Phase 5: first of the new canonical-taxonomy onboarding screens
/// (DRIVER_AND_FLEET_CONTRACT.md sections 1, 6; Phase 5 prompt section 21). Independent of
/// vehicle category and service type - selecting "Fleet Driver" here does not by itself grant a
/// fleet membership; it only routes the driver through [RouteNames.fleetJoin] later in this same
/// chain, where the actual invitation/request flow (server-validated) happens.
class AffiliationSelectionScreen extends StatefulWidget {
  const AffiliationSelectionScreen({super.key});

  @override
  State<AffiliationSelectionScreen> createState() =>
      _AffiliationSelectionScreenState();
}

class _AffiliationSelectionScreenState
    extends State<AffiliationSelectionScreen> {
  String? _selected;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = RegistrationDraftService.instance.value.affiliationType;
  }

  Future<void> _continue() async {
    final value = _selected;
    if (value == null) {
      setState(() => _error = 'Choose how you will drive with TheRain.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    RegistrationDraftService.instance.updateAffiliation(value);
    try {
      await AuthSyncService.instance.saveOnboardingStep('affiliation', {
        'affiliationType': value,
      });
    } catch (_) {
      // Best-effort server save; the local draft already has the value and the review screen
      // re-submits everything at the end, so a transient failure here is not blocking.
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pushNamed(
      context,
      _returnToReview ? RouteNames.review : RouteNames.services,
    );
  }

  bool get _returnToReview {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['returnToReview'] == true;
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
              const StepIndicator(
                current: 2,
                total: 4,
                labels: ['Region', 'Affiliation', 'Services', 'Vehicle'],
              ),
              const SizedBox(height: 26),
              Text(
                'How will you drive with TheRain?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'This determines how your account is managed. You can only belong to one at a time.',
              ),
              const SizedBox(height: 22),
              for (final option in DriverTaxonomy.affiliations) ...[
                OptionCard(
                  label: option.label,
                  subtitle: DriverTaxonomy.affiliationDescriptions[option.value],
                  selected: _selected == option.value,
                  onTap: () => setState(() {
                    _selected = option.value;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Continue',
                isLoading: _isSaving,
                onPressed: _continue,
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
