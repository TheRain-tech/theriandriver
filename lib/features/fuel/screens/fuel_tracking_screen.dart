import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/fuel_tracking_repository.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class FuelTrackingScreen extends StatelessWidget {
  FuelTrackingScreen({super.key});
  final _repository = FuelTrackingRepository();

  @override
  Widget build(BuildContext context) => FutureBuilder<FuelSnapshot>(
    future: _repository.getFuelSnapshot(),
    builder: (context, snapshot) {
      final fuel = snapshot.data;
      if (fuel == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FeatureScaffold(
        title: 'Fuel Tracking',
        children: [
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: fuel.level,
                      strokeWidth: 18,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.border,
                      color: AppColors.success,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_gas_station_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                      Text(
                        '${(fuel.level * 100).round()}%',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const Text(
                        'Good',
                        style: TextStyle(color: AppColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              children: [
                LabeledValue(
                  label: 'Fuel Efficiency',
                  value: '${fuel.efficiencyKmPerLitre} km/L',
                  icon: Icons.speed_rounded,
                ),
                const Divider(height: 28),
                LabeledValue(
                  label: 'Last Update',
                  value: DateFormatter.full(fuel.updatedAt),
                  icon: Icons.update_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Update Fuel',
            icon: Icons.local_gas_station_outlined,
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Fuel level updated'))),
          ),
        ],
      );
    },
  );
}
