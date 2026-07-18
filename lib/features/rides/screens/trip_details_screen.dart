import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/fare_breakdown_card.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/map_preview_card.dart';
import '../../shared/widgets/trip_route_card.dart';

class TripDetailsScreen extends StatelessWidget {
  TripDetailsScreen({super.key, this.tripId});

  final String? tripId;
  final _repository = DriverTripRepository();

  Future<DriverTrip?> _loadTrip() async {
    if (tripId != null) return _repository.getTrip(tripId!);
    final trips = await _repository.getTrips();
    return trips.firstOrNull;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DriverAppBar(
      title: 'Trip Details',
      showBack: true,
      showLogo: false,
      showOnline: true,
    ),
    body: FutureBuilder<DriverTrip?>(
      future: _loadTrip(),
      builder: (context, snapshot) {
        final trip = snapshot.data;
        if (trip == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MapPreviewCard(
                  height: 170,
                  showCar: false,
                  pickupLat: trip.pickupLat,
                  pickupLng: trip.pickupLng,
                  destinationLat: trip.dropOffLat,
                  destinationLng: trip.dropOffLng,
                  routePolyline: trip.routePolyline,
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.calendar_month_outlined,
                              label: 'Trip Date',
                              value: DateFormat(
                                'd MMM y',
                              ).format(trip.createdAt),
                            ),
                          ),
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.schedule_outlined,
                              label: 'Trip Time',
                              value: DateFormat(
                                'h:mm a',
                              ).format(trip.createdAt),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.person_outline_rounded,
                              label: 'Rider',
                              value: trip.riderName,
                            ),
                          ),
                          Expanded(
                            child: LabeledValue(
                              label: 'Trip ID',
                              value: trip.id,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.payments_outlined,
                              label: 'Payment Type',
                              value:
                                  trip.paymentMethod ==
                                      PaymentMethod.mobileMoney
                                  ? 'Mobile Money'
                                  : 'Cash',
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Payment Status'),
                                const SizedBox(height: 5),
                                StatusBadge(
                                  label:
                                      trip.paymentStatus == PaymentStatus.paid
                                      ? 'Paid'
                                      : trip.paymentStatus.name,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TripRouteCard(pickup: trip.pickup, dropOff: trip.dropOff),
                const SizedBox(height: 14),
                FareBreakdownCard(
                  baseFare: (trip.fare * 0.8).roundToDouble(),
                  bonus: (trip.fare * 0.12).roundToDouble(),
                  tip: (trip.fare * 0.08).roundToDouble(),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Download Receipt',
                  icon: Icons.download_rounded,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Receipt download isn't available yet. Contact support if you need a copy of this trip.",
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppOutlineButton(
                  label: 'Get Help',
                  icon: Icons.headset_mic_outlined,
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.contactSupport),
                ),
                const SizedBox(height: 14),
                const AppCard(
                  color: AppColors.primarySoft,
                  child: Row(
                    children: [
                      IconWell(icon: Icons.support_agent_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Need help with this trip?\nOur support team is here for you 24/7.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
