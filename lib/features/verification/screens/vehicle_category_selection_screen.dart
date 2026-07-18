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

/// Phase 5: physical vehicle-category picker - distinct from any ride tier/branding label
/// (DRIVER_AND_FLEET_CONTRACT.md section 3). Last of the taxonomy onboarding screens: a Fleet
/// Driver continues to [RouteNames.fleetJoin] next; everyone else continues straight into the
/// existing document-verification chain, unchanged.
class VehicleCategorySelectionScreen extends StatefulWidget {
  const VehicleCategorySelectionScreen({super.key});

  @override
  State<VehicleCategorySelectionScreen> createState() =>
      _VehicleCategorySelectionScreenState();
}

class _VehicleCategorySelectionScreenState
    extends State<VehicleCategorySelectionScreen> {
  String? _selected;
  bool _isSaving = false;
  String? _error;

  static const _icons = <String, IconData>{
    'motorbike': Icons.two_wheeler,
    'tricycle': Icons.electric_rickshaw,
    'car': Icons.directions_car_outlined,
    'suv': Icons.directions_car_filled_outlined,
    'van': Icons.airport_shuttle_outlined,
    'mini_truck': Icons.local_shipping_outlined,
    'truck': Icons.fire_truck_outlined,
  };

  @override
  void initState() {
    super.initState();
    _selected = RegistrationDraftService.instance.value.vehicleCategory;
  }

  Future<void> _continue() async {
    final value = _selected;
    if (value == null) {
      setState(() => _error = 'Choose the type of vehicle you will use.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    RegistrationDraftService.instance.updateVehicleCategory(value);
    try {
      await AuthSyncService.instance.saveOnboardingStep('vehicle_category', {
        'vehicleCategory': value,
      });
    } catch (_) {
      // Best-effort; see affiliation_selection_screen.dart for the same reasoning.
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (_returnToReview) {
      Navigator.pushNamed(context, RouteNames.review);
      return;
    }
    final affiliationType =
        RegistrationDraftService.instance.value.affiliationType;
    Navigator.pushNamed(
      context,
      affiliationType == 'fleet'
          ? RouteNames.fleetJoin
          : RouteNames.nationalId,
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
                current: 4,
                total: 4,
                labels: ['Region', 'Affiliation', 'Services', 'Vehicle'],
              ),
              const SizedBox(height: 26),
              Text(
                'What vehicle will you drive?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the vehicle type. You\'ll add its details and documents next.',
              ),
              const SizedBox(height: 22),
              for (final option in DriverTaxonomy.vehicleCategories) ...[
                OptionCard(
                  label: option.label,
                  icon: _icons[option.value],
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
