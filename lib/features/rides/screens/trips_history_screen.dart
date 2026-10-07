import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
  // Stable, never-translated internal keys - compared in the switch below and used as the
  // ChoiceChip's own selection identity. _filterLabel maps each to its displayed text, the same
  // split driver_dashboard_screen.dart's _blockedReason/_blockedReasonDisplay already uses for
  // exactly this reason: translating the value used for comparison would silently break filtering.
  String _filter = 'Completed';
  String _query = '';

  String _filterLabel(String filter, DriverCopy l) => switch (filter) {
    'All' => l.t('All', 'Toutes'),
    'Completed' => l.t('Completed', 'Terminées'),
    'Cancelled' => l.t('Cancelled', 'Annulées'),
    'Missed' => l.t('Missed', 'Manquées'),
    'Today' => l.t('Today', "Aujourd'hui"),
    _ => filter,
  };

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
    appBar: const DriverAppBar(showOnline: true),
    body: SafeArea(
      top: false,
      child: FutureBuilder<List<DriverTrip>>(
        future: _repository.getTrips(),
        builder: (context, snapshot) {
          final trips = (snapshot.data ?? const <DriverTrip>[]).where((trip) {
            final matchesQuery =
                _query.isEmpty ||
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
          }).toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.t('Trips', 'Courses'), style: Theme.of(context).textTheme.displaySmall),
                Text(l.t('View and manage your trip history', 'Consultez et gérez votre historique de courses')),
                SizedBox(height: 18),
                SearchFilterBar(
                  hint: l.t('Search trips, locations or amounts...', 'Rechercher des courses, lieux ou montants...'),
                  onChanged: (value) => setState(() => _query = value),
                ),
                SizedBox(height: 14),
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
                            label: Text(_filterLabel(filter, l)),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                for (final trip in trips) ...[
                  _TripHistoryCard(trip: trip),
                  SizedBox(height: 12),
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
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.trip});
  final DriverTrip trip;

  String _statusLabel(DriverCopy l) => switch (trip.status) {
    TripStatus.completed => l.t('Completed', 'Terminée'),
    TripStatus.cancelled => l.t('Cancelled', 'Annulée'),
    TripStatus.missed => l.t('Missed', 'Manquée'),
    TripStatus.requested => l.t('Requested', 'Demandée'),
    TripStatus.accepted => l.t('Accepted', 'Acceptée'),
    TripStatus.goingToPickup => l.t('Going to Pickup', 'En route vers la prise en charge'),
    TripStatus.arrived => l.t('Arrived', 'Arrivé'),
    TripStatus.inProgress => l.t('In Progress', 'En cours'),
  };

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return AppCard(
    onTap: () => Navigator.pushNamed(
      context,
      RouteNames.tripDetails,
      arguments: trip.id,
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '${trip.createdAt.day}/${trip.createdAt.month}/${trip.createdAt.year} • ${trip.createdAt.hour.toString().padLeft(2, '0')}:${trip.createdAt.minute.toString().padLeft(2, '0')}',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successSoftFor(context),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _statusLabel(l),
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
                SizedBox(
                  height: 30,
                  child: VerticalDivider(color: AppColors.borderFor(context)),
                ),
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.success,
                  size: 21,
                ),
              ],
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.pickup,
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 26),
                  Text(
                    trip.dropOff,
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
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
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  trip.paymentMethod == PaymentMethod.cash
                      ? l.t('Cash', 'Espèces')
                      : l.t('Mobile Money', 'Mobile Money'),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  }
}
