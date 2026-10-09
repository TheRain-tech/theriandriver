import 'dart:async';

import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/trip_earnings_card.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/rating_stars.dart';

class TripCompletedScreen extends StatefulWidget {
  const TripCompletedScreen({super.key});

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  final _repository = DriverTripRepository();
  final _rideRepository = RideRepository();
  StreamSubscription<DriverTrip?>? _tripSubscription;
  DriverTrip? _liveTrip;
  int _rating = 5;
  bool _submitting = false;
  bool _submitted = false;

  Future<void> _submitRating(DriverTrip? trip) async {
    if (trip == null || _submitting || _submitted) {
      if (trip == null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.trips,
          (route) => false,
        );
      }
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repository.submitRiderRating(rideId: trip.id, rating: _rating);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.trips,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Could not submit your rating: $error',
              "Impossible d'envoyer votre note : $error",
            ),
          ),
        ),
      );
    }
  }

  bool _watching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watching) return;
    final passed = ModalRoute.of(context)?.settings.arguments as DriverTrip?;
    if (passed == null || passed.id.isEmpty) return;
    _watching = true;
    // The commission is stamped by the server as the trip completes; follow the ride so the breakdown
    // fills in the moment it is there.
    _tripSubscription = _rideRepository.watchRide(passed.id).listen((trip) {
      if (trip != null && mounted) setState(() => _liveTrip = trip);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip =
        _liveTrip ?? ModalRoute.of(context)?.settings.arguments as DriverTrip?;
    final copy = DriverCopy.of(context);

    final paymentMethod = trip?.paymentMethod == PaymentMethod.mobileMoney
        ? copy.t('Mobile Money', 'Mobile Money')
        : copy.t('Cash', 'Espèces');

    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor: AppColors.successSoftFor(context),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 82,
                  color: AppColors.success,
                ),
              ),
              SizedBox(height: 20),
              Text(
                copy.t('Trip Completed', 'Course terminée'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: 8),
              Text(
                copy.t(
                  "Great job! You've completed the trip successfully.",
                  'Bravo ! Vous avez terminé la course avec succès.',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 22),
              if (trip != null) ...[
                TripEarningsCard(trip: trip),
                SizedBox(height: 14),
              ],
              AppCard(
                child: Row(
                  children: [
                    IconWell(
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                      background: AppColors.successSoftFor(context),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: LabeledValue(
                        label: copy.t('Payment Method', 'Mode de paiement'),
                        value: paymentMethod,
                      ),
                    ),
                    StatusBadge(label: copy.t('Paid', 'Payé')),
                  ],
                ),
              ),
              SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.t('Rate your rider', 'Évaluez votre passager'),
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      copy.t(
                        'Your feedback helps us improve.',
                        'Vos commentaires nous aident à nous améliorer.',
                      ),
                    ),
                    SizedBox(height: 8),
                    RatingStars(
                      initialRating: _rating,
                      onChanged: (value) => setState(() => _rating = value),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              PrimaryButton(
                label: copy.t('Submit Rating', 'Envoyer la note'),
                isLoading: _submitting,
                onPressed: _submitting ? null : () => _submitRating(trip),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  RouteNames.tripDetails,
                  arguments: trip?.id,
                ),
                icon: Icon(Icons.receipt_long_outlined),
                label: Text(copy.t('View Receipt', 'Voir le reçu')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
