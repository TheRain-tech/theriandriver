import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/search_filter_bar.dart';

class TripsHistoryScreen extends StatefulWidget {
  const TripsHistoryScreen({super.key});

  @override
  State<TripsHistoryScreen> createState() => _TripsHistoryScreenState();
}

class _TripsHistoryScreenState extends State<TripsHistoryScreen> {
  final _repository = DriverTripRepository();
  String _filter = 'Completed';
  String _query = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DriverAppBar(showOnline: true),
    body: SafeArea(
      top: false,
      child: FutureBuilder<List<DriverTrip>>(
        future: _repository.getTrips(),
        builder: (context, snapshot) {
          final trips = (snapshot.data ?? const <DriverTrip>[])
              .where((trip) {
                final matchesQuery = _query.isEmpty ||
                    trip.pickup.toLowerCase().contains(_query.toLowerCase()) ||
                    trip.dropOff.toLowerCase().contains(_query.toLowerCase());
                if (!matchesQuery) return false;

                return switch (_filter) {
                  'Completed' => trip.status == TripStatus.completed,
                  'Cancelled' => trip.status == TripStatus.cancelled,
                  'Missed' => trip.status == TripStatus.missed,
                  'Today' => DateUtils.isSameDay(trip.createdAt, DateTime.now()),
                  _ => true,
                };
              })
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trips', style: Theme.of(context).textTheme.displaySmall),
                const Text('View and manage your trip history'),
                const SizedBox(height: 18),
                SearchFilterBar(
                  hint: 'Search trips, locations or amounts...',
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in [
                        'All',
                        'Completed',
                        'Cancelled',
                        'Missed',
                        'Today',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final trip in trips) ...[
                  _TripHistoryCard(trip: trip),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 2),
  );
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.trip});
  final DriverTrip trip;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => Navigator.pushNamed(
      context,
      RouteNames.tripDetails,
      arguments: trip.id,
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${trip.createdAt.day}/${trip.createdAt.month}/${trip.createdAt.year} • ${trip.createdAt.hour.toString().padLeft(2, '0')}:${trip.createdAt.minute.toString().padLeft(2, '0')}',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                trip.status == TripStatus.completed
                    ? 'Completed'
                    : trip.status.name,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
                SizedBox(
                  height: 30,
                  child: VerticalDivider(color: AppColors.border),
                ),
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.success,
                  size: 21,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.pickup,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    trip.dropOff,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(trip.fare),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trip.paymentMethod == PaymentMethod.cash
                      ? 'Cash'
                      : 'Mobile Money',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
