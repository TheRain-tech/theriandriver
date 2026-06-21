import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/fare_breakdown_card.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/rating_stars.dart';

class TripCompletedScreen extends StatelessWidget {
  const TripCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trip = ModalRoute.of(context)?.settings.arguments as DriverTrip?;
    final fare = trip?.fare ?? 2500.0;

    // Decompose fare into parts for styling purposes
    final baseFare = fare * 0.8;
    final bonus = fare * 0.12;
    final tip = fare * 0.08;

    final paymentMethod = trip?.paymentMethod == PaymentMethod.mobileMoney
        ? 'Mobile Money'
        : 'Cash';

    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 58,
                backgroundColor: AppColors.successSoft,
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 82,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Trip Completed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                "Great job! You've completed the trip successfully.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FareBreakdownCard(
                baseFare: baseFare.roundToDouble(),
                bonus: bonus.roundToDouble(),
                tip: tip.roundToDouble(),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Row(
                  children: [
                    const IconWell(
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: LabeledValue(
                        label: 'Payment Method',
                        value: paymentMethod,
                      ),
                    ),
                    const StatusBadge(label: 'Paid'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate your rider',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('Your feedback helps us improve.'),
                    SizedBox(height: 8),
                    RatingStars(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Submit Rating',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.trips,
                  (route) => false,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  RouteNames.tripDetails,
                  arguments: trip?.id,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Receipt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
