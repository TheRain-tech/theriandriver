import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../data/models/app_enums.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../services/road_alert_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../rides/street_pickup/street_pickup_sheet.dart';

/// Floating "+" button over the dashboard map. Opens Quick Actions:
/// - Street Pickup: book a passenger the driver picked up on the street (see
///   street_pickup_sheet.dart / RideRepository.createStreetPickupRide).
/// - Report Road Issue: report a road-safety condition (police/speed control,
///   hazard, road works) so nearby TheRain drivers can be warned in real time.
///   Deliberately separate from SOS (an emergency button that already exists
///   on trip screens) - this is road-condition information, not a personal
///   emergency.
class RoadAlertButton extends StatefulWidget {
  const RoadAlertButton({super.key});

  @override
  State<RoadAlertButton> createState() => _RoadAlertButtonState();
}

enum _QuickAction { streetPickup, roadAlert }

class _RoadAlertButtonState extends State<RoadAlertButton> {
  bool _sending = false;

  Future<void> _openQuickActions() async {
    final action = await showModalBottomSheet<_QuickAction>(
      context: context,
      backgroundColor: AppColors.surfaceFor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _QuickActionsSheet(parentContext: context),
    );
    if (!mounted) return;
    switch (action) {
      case _QuickAction.streetPickup:
        await _startStreetPickup();
      case _QuickAction.roadAlert:
        await _openActionSheet();
      case null:
        break;
    }
  }

  Future<void> _startStreetPickup() async {
    final l = DriverCopy.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final profile = DriverProfileService.instance.profile.value;
    if (profile.currentRideId != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'Finish your current trip before starting a street pickup.',
              'Terminez votre course actuelle avant de prendre un passager dans la rue.',
            ),
          ),
        ),
      );
      return;
    }
    if (profile.onlineStatus == DriverOnlineStatus.offline) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'Go online to start a street pickup.',
              'Passez en ligne pour prendre un passager dans la rue.',
            ),
          ),
        ),
      );
      return;
    }
    final trip = await StreetPickupSheet.show(context);
    if (trip == null || !mounted) return;
    TripService.instance.activeTrip.value = trip;
    try {
      await LocationService.instance.setCurrentRide(trip.id);
    } catch (_) {
      // Location publishing will resume from the active-trip screen.
    }
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      RouteNames.tripInProgress,
      // Opens the "Share Trip Details" prompt once the trip screen is up.
      arguments: true,
    );
  }

  Future<void> _openActionSheet() async {
    final type = await showModalBottomSheet<RoadAlertType>(
      context: context,
      backgroundColor: AppColors.surfaceFor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _RoadAlertActionSheet(parentContext: context),
    );
    if (type == null || !mounted) return;
    final confirmed = await _confirmAlert(type);
    if (confirmed != true || !mounted) return;
    await _sendAlert(type);
  }

  Future<bool?> _confirmAlert(RoadAlertType type) {
    final l = DriverCopy.of(context);
    final title = switch (type) {
      RoadAlertType.policeSpeedControl =>
        l.t('Police / Speed Control Ahead?', 'Police / Contrôle de vitesse à venir ?'),
      RoadAlertType.traffic => l.t('Traffic Ahead?', 'Circulation dense à venir ?'),
      RoadAlertType.roadHazard =>
        l.t('Road Hazard Ahead?', 'Danger routier à venir ?'),
      RoadAlertType.roadWorks =>
        l.t('Road Works Ahead?', 'Travaux routiers à venir ?'),
    };
    final body = switch (type) {
      RoadAlertType.policeSpeedControl => l.t(
        'Let nearby TheRain drivers know that police or speed control may be ahead so they can reduce their speed and drive safely.',
        'Informez les chauffeurs TheRain à proximité qu\'un contrôle de police ou de vitesse est peut-être à venir, afin qu\'ils puissent réduire leur vitesse et conduire prudemment.',
      ),
      RoadAlertType.traffic => l.t(
        'Let nearby TheRain drivers know that traffic has been reported near your location.',
        'Informez les chauffeurs TheRain à proximité qu\'une circulation dense a été signalée près de votre position.',
      ),
      RoadAlertType.roadHazard => l.t(
        'Let nearby TheRain drivers know about a hazard on the road ahead so they can drive carefully.',
        'Informez les chauffeurs TheRain à proximité d\'un danger sur la route afin qu\'ils puissent conduire prudemment.',
      ),
      RoadAlertType.roadWorks => l.t(
        'Let nearby TheRain drivers know about road works ahead so they can drive carefully.',
        'Informez les chauffeurs TheRain à proximité de travaux routiers afin qu\'ils puissent conduire prudemment.',
      ),
    };
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceFor(dialogContext),
        icon: Icon(Icons.local_police_rounded, color: AppColors.primary, size: 32),
        title: Text(
          title,
          style: TextStyle(color: AppColors.textPrimaryFor(dialogContext)),
        ),
        content: Text(
          body,
          style: TextStyle(color: AppColors.textSecondaryFor(dialogContext)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.t('Cancel', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l.t('Send Alert', 'Envoyer l\'alerte')),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAlert(RoadAlertType type) async {
    if (_sending) return;
    setState(() => _sending = true);
    final l = DriverCopy.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await RoadAlertService.report(type);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'Thanks - nearby drivers have been alerted.',
              'Merci - les chauffeurs à proximité ont été alertés.',
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : l.t(
                    'Unable to send this alert. Please try again.',
                    'Impossible d\'envoyer cette alerte. Veuillez réessayer.',
                  ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _sending ? null : _openQuickActions,
        child: SizedBox(
          width: 48,
          height: 48,
          child: _sending
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet({required this.parentContext});

  // See _RoadAlertActionSheet.parentContext.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(parentContext);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderFor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l.t('Quick Actions', 'Actions rapides'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 12),
            _QuickActionTile(
              icon: Icons.person_add_rounded,
              iconColor: AppColors.primary,
              title: l.t('Street Pickup', 'Prise en charge dans la rue'),
              subtitle: l.t(
                'Book a ride for a passenger you picked up',
                'Enregistrez une course pour un passager pris dans la rue',
              ),
              onTap: () => Navigator.pop(context, _QuickAction.streetPickup),
            ),
            Divider(color: AppColors.borderFor(context)),
            _QuickActionTile(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.warning,
              title: l.t('Report Road Issue', 'Signaler un problème routier'),
              subtitle: l.t(
                'Report police, traffic, a hazard or road works',
                'Signalez la police, la circulation, un danger ou des travaux',
              ),
              onTap: () => Navigator.pop(context, _QuickAction.roadAlert),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryFor(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondaryFor(context),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textSecondaryFor(context),
      ),
      onTap: onTap,
    );
  }
}

class _RoadAlertActionSheet extends StatelessWidget {
  const _RoadAlertActionSheet({required this.parentContext});

  // The sheet's own BuildContext does not carry the driver's language
  // preference reliably once DriverCopy.of walks InheritedWidgets mounted
  // above the bottom-sheet route, so copy is resolved from the screen that
  // opened the sheet instead.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(parentContext);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderFor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l.t('Report Road Alert', 'Signaler une alerte routière'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 12),
            _RoadAlertOptionTile(
              icon: Icons.local_police_rounded,
              iconColor: AppColors.primary,
              label: l.t(
                'Police / Speed Control Ahead',
                'Police / Contrôle de vitesse',
              ),
              onTap: () =>
                  Navigator.pop(context, RoadAlertType.policeSpeedControl),
            ),
            _RoadAlertOptionTile(
              icon: Icons.traffic_rounded,
              iconColor: AppColors.warning,
              label: l.t('Traffic', 'Circulation dense'),
              onTap: () => Navigator.pop(context, RoadAlertType.traffic),
            ),
            _RoadAlertOptionTile(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.warning,
              label: l.t('Road Hazard', 'Danger routier'),
              onTap: () => Navigator.pop(context, RoadAlertType.roadHazard),
            ),
            _RoadAlertOptionTile(
              icon: Icons.construction_rounded,
              iconColor: AppColors.warning,
              label: l.t('Road Works', 'Travaux routiers'),
              onTap: () => Navigator.pop(context, RoadAlertType.roadWorks),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.t('Cancel', 'Annuler')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadAlertOptionTile extends StatelessWidget {
  const _RoadAlertOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.12),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryFor(context),
        ),
      ),
      onTap: onTap,
    );
  }
}
