import '../../../core/localization/driver_copy.dart';
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
import '../../shared/widgets/trip_earnings_card.dart';
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
    appBar: DriverAppBar(
      title: DriverCopy.of(context).t('Trip Details', 'Détails de la course'),
      showBack: true,
      showLogo: false,
      showOnline: true,
    ),
    body: FutureBuilder<DriverTrip?>(
      future: _loadTrip(),
      builder: (context, snapshot) {
        final trip = snapshot.data;
        if (trip == null) {
          return Center(child: CircularProgressIndicator());
        }
        final copy = DriverCopy.of(context);
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
                  driverRideType: trip.rideType,
                ),
                SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.calendar_month_outlined,
                              label: copy.t('Trip Date', 'Date de la course'),
                              value: DateFormat(
                                'd MMM y',
                              ).format(trip.createdAt),
                            ),
                          ),
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.schedule_outlined,
                              label: copy.t('Trip Time', 'Heure de la course'),
                              value: DateFormat(
                                'h:mm a',
                              ).format(trip.createdAt),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: LabeledValue(
                              icon: Icons.person_outline_rounded,
                              label: copy.t('Rider', 'Passager'),
                              value: trip.riderName,
                            ),
                          ),
                          Expanded(
                            child: LabeledValue(
                              label: copy.t('Trip ID', 'ID de la course'),
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
                              label: copy.t('Payment Type', 'Mode de paiement'),
                              value:
                                  trip.paymentMethod ==
                                      PaymentMethod.mobileMoney
                                  ? copy.t('Mobile Money', 'Mobile Money')
                                  : copy.t('Cash', 'Espèces'),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.t('Payment Status', 'Statut du paiement'),
                                ),
                                SizedBox(height: 5),
                                StatusBadge(
                                  label:
                                      trip.paymentStatus == PaymentStatus.paid
                                      ? copy.t('Paid', 'Payé')
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
                SizedBox(height: 14),
                TripRouteCard(pickup: trip.pickup, dropOff: trip.dropOff),
                SizedBox(height: 14),
                TripEarningsCard(trip: trip),
                SizedBox(height: 18),
                PrimaryButton(
                  label: copy.t('Download Receipt', 'Télécharger le reçu'),
                  icon: Icons.download_rounded,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        DriverCopy.current.t(
                          "Receipt download isn't available yet. Contact support if you need a copy of this trip.",
                          "Le téléchargement du reçu n'est pas encore disponible. Contactez l'assistance si vous avez besoin d'une copie de cette course.",
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                AppOutlineButton(
                  label: copy.t('Get Help', "Obtenir de l'aide"),
                  icon: Icons.headset_mic_outlined,
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.contactSupport),
                ),
                SizedBox(height: 14),
                AppCard(
                  color: AppColors.primarySoftFor(context),
                  child: Row(
                    children: [
                      IconWell(icon: Icons.support_agent_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          copy.t(
                            'Need help with this trip?\nOur support team is here for you 24/7.',
                            "Besoin d'aide avec cette course ?\nNotre équipe d'assistance est disponible 24/7.",
                          ),
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
