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
import '../widgets/active_trip_banner.dart';

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
  late Future<List<DriverTrip>> _tripsFuture;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _tripsFuture = _repository.getTrips();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final l = DriverCopy.current;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.t('Remove from history?', 'Retirer de l\'historique ?')),
        content: Text(
          l.t(
            'This will remove $count trip(s) from your own history. It won\'t affect the rider\'s history or your earnings records.',
            'Cela retirera $count course(s) de votre propre historique. Cela n\'affecte pas l\'historique du passager ni vos revenus.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.t('Cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.t('Remove', 'Retirer')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _repository.hideTripsFromHistory(_selectedIds);
      if (!mounted) return;
      setState(() {
        _tripsFuture = _repository.getTrips();
        _selectionMode = false;
        _selectedIds.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('Error: $error', 'Erreur : $error'))),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

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
    appBar: DriverAppBar(
      title: _selectionMode ? l.t('${_selectedIds.length} selected', '${_selectedIds.length} sélectionnée(s)') : l.trips,
      showBack: true,
      showLogo: false,
      showOnline: true,
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 4),
    body: SafeArea(
      top: false,
      child: FutureBuilder<List<DriverTrip>>(
        future: _tripsFuture,
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
                const ActiveTripBanner(),
                Row(
                  children: [
                    Expanded(
                      child: Text(l.t('Trips', 'Courses'), style: Theme.of(context).textTheme.displaySmall),
                    ),
                    if (trips.isNotEmpty)
                      TextButton(
                        onPressed: _selectionMode
                            ? _exitSelectionMode
                            : () => setState(() => _selectionMode = true),
                        child: Text(_selectionMode ? l.t('Cancel', 'Annuler') : l.t('Select', 'Sélectionner')),
                      ),
                  ],
                ),
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
                  _TripHistoryCard(
                    trip: trip,
                    selectionMode: _selectionMode,
                    selected: _selectedIds.contains(trip.id),
                    onToggleSelected: () => _toggleSelection(trip.id),
                    onEnterSelectionMode: () {
                      setState(() => _selectionMode = true);
                      _toggleSelection(trip.id);
                    },
                  ),
                  SizedBox(height: 12),
                ],
                if (_selectionMode) ...[
                  SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _selectedIds.isEmpty || _deleting ? null : _deleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      _deleting
                          ? l.t('Removing...', 'Suppression...')
                          : l.t('Remove (${_selectedIds.length})', 'Retirer (${_selectedIds.length})'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({
    required this.trip,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onEnterSelectionMode,
  });
  final DriverTrip trip;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final VoidCallback? onEnterSelectionMode;

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
    return GestureDetector(
    onLongPress: selectionMode ? null : onEnterSelectionMode,
    child: AppCard(
    // A trip that's still under way reopens its live navigation screen; only finished trips
    // (completed / cancelled / missed) go to the Trip Details receipt. In selection mode, a tap
    // toggles selection instead of navigating away from the list.
    onTap: selectionMode
        ? onToggleSelected
        : () => activeTripRouteFor(trip.status) != null
        ? openActiveTrip(context, trip)
        : Navigator.pushNamed(
            context,
            RouteNames.tripDetails,
            arguments: trip.id,
          ),
    color: selected ? AppColors.primarySoftFor(context) : null,
    borderColor: selected ? AppColors.primary : null,
    child: Column(
      children: [
        Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondaryFor(context),
              ),
              SizedBox(width: 8),
            ],
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
            if (trip.isStreetPickup) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoftFor(context),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l.t('Street Pickup', 'Prise dans la rue'),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 6),
            ],
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
    ),
  );
  }
}
