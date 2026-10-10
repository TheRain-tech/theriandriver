import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/scheduled_ride_offer.dart';
import '../../../data/repositories/scheduled_ride_repository.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// Scheduled rides this driver can pre-accept ahead of their normal activation window (8 minutes
/// before pickup) - see node-api/services/scheduledRide.service.js#listNearbyScheduledRidesForDriver.
/// Accepting reserves it (scheduledRide.service.js#acceptScheduledRide, transaction-guarded
/// against two drivers racing for the same one); the real `rides` offer still only arrives
/// through the normal ride-request flow once the scheduled pickup time actually approaches.
class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  final _repository = ScheduledRideRepository();
  late Future<List<ScheduledRideOffer>> _future;
  final _acceptingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _repository.nearbyScheduledRides();
  }

  Future<void> _refresh() async {
    final next = _repository.nearbyScheduledRides();
    setState(() => _future = next);
    await next;
  }

  Future<void> _accept(ScheduledRideOffer offer) async {
    if (_acceptingIds.contains(offer.id)) return;
    setState(() => _acceptingIds.add(offer.id));
    final l = DriverCopy.of(context);
    try {
      await _repository.acceptScheduledRide(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'Reserved. We\'ll offer you the real ride as pickup time approaches.',
              "Réservé. Nous vous proposerons la vraie course à l'approche de l'heure de prise en charge.",
            ),
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : l.t('Could not reserve this ride.', "Impossible de réserver cette course.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _acceptingIds.remove(offer.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return FeatureScaffold(
      title: l.t('Scheduled Rides', 'Courses planifiées'),
      children: [
        FutureBuilder<List<ScheduledRideOffer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _EmptyState(
                message: l.t(
                  'Scheduled rides could not be loaded.',
                  'Les courses planifiées n\'ont pas pu être chargées.',
                ),
                onRetry: _refresh,
              );
            }
            final offers = snapshot.data ?? const <ScheduledRideOffer>[];
            if (offers.isEmpty) {
              return _EmptyState(
                message: l.t(
                  'No scheduled rides near you right now.',
                  'Aucune course planifiée près de vous pour le moment.',
                ),
                onRetry: _refresh,
              );
            }
            return Column(
              children: [
                for (final offer in offers) ...[
                  _ScheduledRideCard(
                    offer: offer,
                    accepting: _acceptingIds.contains(offer.id),
                    onAccept: () => _accept(offer),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(28.0),
          child: Text(message, textAlign: TextAlign.center),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l.t('Refresh', 'Actualiser')),
        ),
      ],
    );
  }
}

class _ScheduledRideCard extends StatelessWidget {
  const _ScheduledRideCard({
    required this.offer,
    required this.accepting,
    required this.onAccept,
  });

  final ScheduledRideOffer offer;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(icon: Icons.schedule_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('EEE d MMM, hh:mm a').format(offer.scheduledPickupAt),
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.format(offer.fareAmount),
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AddressRow(
            icon: Icons.radio_button_checked_rounded,
            color: AppColors.primary,
            address: offer.pickupAddress,
          ),
          const SizedBox(height: 6),
          _AddressRow(
            icon: Icons.location_on_rounded,
            color: AppColors.danger,
            address: offer.destinationAddress,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: accepting ? null : onAccept,
              child: accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.t('Accept ride', 'Accepter la course')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.color,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address.isEmpty
                ? DriverCopy.of(context).t('Address unavailable', 'Adresse indisponible')
                : address,
            style: TextStyle(color: AppColors.textSecondaryFor(context), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
