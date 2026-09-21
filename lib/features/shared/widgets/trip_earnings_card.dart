import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/driver_trip.dart';
import '../../../theme/app_colors.dart';
import 'feature_templates.dart';

/// "Trip Fare / TheRain Commission 15% / Your Earnings" for a completed trip. Every number is one the server
/// stored on the ride when it completed (the fare that was booked and paid, the Super Admin's commission
/// rate at that moment and the amounts computed from them) - the app never calculates or assumes a fare,
/// a rate or a split. Until the server has written them only the trip fare is shown.
class TripEarningsCard extends StatelessWidget {
  const TripEarningsCard({required this.trip, super.key});

  final DriverTrip trip;

  static String percentText(double percent) =>
      percent == percent.roundToDouble()
      ? percent.round().toString()
      : percent.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final percent = trip.commissionRatePercent;
    final commission = trip.commissionAmount;
    final earnings = trip.driverEarnings;
    final settled = percent != null && commission != null && earnings != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('Fare Breakdown', 'Détail du tarif'),
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _row(context, copy.t('Trip Fare', 'Tarif de la course'), trip.fare),
          if (settled) ...[
            _row(
              context,
              copy.t(
                'TheRain Commission ${percentText(percent)}%',
                'Commission TheRain ${percentText(percent)} %',
              ),
              -commission,
              color: AppColors.danger,
            ),
            const Divider(height: 28),
            _row(
              context,
              copy.t('Your Earnings', 'Vos gains'),
              earnings,
              isTotal: true,
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              copy.t(
                'Commission and earnings appear here as soon as the trip is settled.',
                'La commission et vos gains apparaissent ici dès que la course est réglée.',
              ),
              style: TextStyle(color: AppColors.textSecondaryFor(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double value, {
    Color? color,
    bool isTotal = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value < 0
              ? '- ${CurrencyFormatter.format(-value)}'
              : CurrencyFormatter.format(value),
          style: TextStyle(
            color: color ?? AppColors.textPrimaryFor(context),
            fontSize: isTotal ? 22 : 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
