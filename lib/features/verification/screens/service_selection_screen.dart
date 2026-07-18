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

/// Phase 5: service-capability picker - a driver may offer ride hailing, delivery, or both.
/// Deliberately a separate axis from [RouteNames.vehicleCategory] and affiliation
/// (DRIVER_AND_FLEET_CONTRACT.md section 1's invariant: these three must never be conflated).
class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() =>
      _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  Set<String> _selected = {};
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = RegistrationDraftService.instance.value.serviceTypes.toSet();
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
      _error = null;
    });
  }

  Future<void> _continue() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Choose at least one service you can offer.');
      return;
    }
    setState(() => _isSaving = true);
    final serviceTypes = _selected.toList(growable: false);
    RegistrationDraftService.instance.updateServiceTypes(serviceTypes);
    try {
      await AuthSyncService.instance.saveOnboardingStep('services', {
        'serviceTypes': serviceTypes,
      });
    } catch (_) {
      // Best-effort; see affiliation_selection_screen.dart for the same reasoning.
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pushNamed(
      context,
      _returnToReview ? RouteNames.review : RouteNames.vehicleCategory,
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
                current: 3,
                total: 4,
                labels: ['Region', 'Affiliation', 'Services', 'Vehicle'],
              ),
              const SizedBox(height: 26),
              Text(
                'What services will you offer?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Select one or both. You can change this later.'),
              const SizedBox(height: 22),
              for (final option in DriverTaxonomy.serviceTypes) ...[
                OptionCard(
                  label: option.label,
                  icon: option.value == 'delivery'
                      ? Icons.local_shipping_outlined
                      : Icons.directions_car_outlined,
                  selected: _selected.contains(option.value),
                  onTap: () => _toggle(option.value),
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
