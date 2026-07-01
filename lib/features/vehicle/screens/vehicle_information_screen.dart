import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_vehicle.dart';
import '../../../data/repositories/driver_vehicle_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class VehicleInformationScreen extends StatelessWidget {
  final DriverVehicle? vehicle;

  VehicleInformationScreen({super.key, this.vehicle});
  final _repository = DriverVehicleRepository();

  @override
  Widget build(BuildContext context) {
    if (vehicle != null) {
      return _buildContent(context, vehicle!);
    }
    return FutureBuilder<List<DriverVehicle>>(
      future: _repository.getVehicles(),
      builder: (context, snapshot) {
        final v = snapshot.data?.first;
        if (v == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildContent(context, v);
      },
    );
  }

  Widget _buildContent(BuildContext context, DriverVehicle vehicle) =>
      FeatureScaffold(
        title: 'Vehicle Information',
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              size: 150,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            vehicle.model,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(vehicle.plateNumber),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LabeledValue(
                        label: 'Vehicle Type',
                        value: vehicle.type,
                      ),
                    ),
                    Expanded(
                      child: LabeledValue(
                        label: 'Plate Type',
                        value: vehicle.plateType,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: LabeledValue(label: 'Color', value: vehicle.color),
                    ),
                    Expanded(
                      child: LabeledValue(
                        label: 'Seats',
                        value: '${vehicle.seats}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Manage Documents',
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.vehicleDocuments),
          ),
        ],
      );
}
