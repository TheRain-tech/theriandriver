import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_vehicle.dart';
import '../../../data/repositories/driver_vehicle_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class VehicleManagementScreen extends StatelessWidget {
  VehicleManagementScreen({super.key});
  final _repository = DriverVehicleRepository();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DriverVehicle>>(
    future: _repository.getVehicles(),
    builder: (context, snapshot) {
      final vehicles = snapshot.data ?? const <DriverVehicle>[];
      return FeatureScaffold(
        title: 'My Vehicles',
        children: [
          for (final vehicle in vehicles) ...[
            AppCard(
              onTap: () => Navigator.pushNamed(
                context,
                RouteNames.vehicleInformation,
                arguments: vehicle,
              ),
              child: Row(
                children: [
                  const IconWell(icon: Icons.directions_car_rounded, size: 62),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.model,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(vehicle.plateNumber),
                        const SizedBox(height: 7),
                        if (vehicle.isDefault)
                          const StatusBadge(
                            label: 'Default Vehicle',
                            showDot: false,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 10),
          AppOutlineButton(
            label: 'Add New Vehicle',
            icon: Icons.add_rounded,
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.addVehicle),
          ),
        ],
      );
    },
  );
}
