import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../services/road_alert_service.dart';
import '../../../theme/app_colors.dart';

/// Floating "+" button over the dashboard map that lets a driver report a
/// road-safety condition (police/speed control, hazard, road works) so
/// nearby TheRain drivers can be warned in real time. Deliberately separate
/// from SOS (an emergency button that already exists on trip screens) - this
/// is road-condition information, not a personal emergency.
class RoadAlertButton extends StatefulWidget {
  const RoadAlertButton({super.key});

  @override
  State<RoadAlertButton> createState() => _RoadAlertButtonState();
}

class _RoadAlertButtonState extends State<RoadAlertButton> {
  bool _sending = false;

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
        onTap: _sending ? null : _openActionSheet,
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
