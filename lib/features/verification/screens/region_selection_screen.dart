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

/// Phase 5: canonical region picker, replacing the free-text `cityRegion` field theraindriver's
/// onboarding previously collected (see theraindriver/AGENTS.md's regionId note). Values come
/// from therainAdmin/docs/platform/contracts/region-registry.json - do not add a second,
/// locally-invented region list.
class RegionSelectionScreen extends StatefulWidget {
  const RegionSelectionScreen({super.key});

  @override
  State<RegionSelectionScreen> createState() => _RegionSelectionScreenState();
}

class _RegionSelectionScreenState extends State<RegionSelectionScreen> {
  String? _selected;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = RegistrationDraftService.instance.value.regionId;
  }

  Future<void> _continue() async {
    final value = _selected;
    if (value == null) {
      setState(() => _error = 'Choose the region you will operate in.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    RegistrationDraftService.instance.updateRegion(value);
    try {
      // First of the taxonomy screens - creates the node-api driver record (idempotent) so the
      // remaining steps' PATCH /api/drivers/me/onboarding calls have a record to update. See
      // AuthSyncService#createDriverApplication; regionId is the only field it requires.
      await AuthSyncService.instance.createDriverApplication(regionId: value);
    } catch (_) {
      // Best-effort; see affiliation_selection_screen.dart for the same reasoning.
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pushNamed(
      context,
      _returnToReview ? RouteNames.review : RouteNames.affiliation,
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
                current: 1,
                total: 4,
                labels: ['Region', 'Affiliation', 'Services', 'Vehicle'],
              ),
              const SizedBox(height: 26),
              Text(
                'Which region will you operate in?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'TheRain assigns rides, support, and admin review by region.',
              ),
              const SizedBox(height: 22),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  for (final option in DriverTaxonomy.regions)
                    OptionCard(
                      label: option.label,
                      selected: _selected == option.value,
                      onTap: () => setState(() {
                        _selected = option.value;
                        _error = null;
                      }),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
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
