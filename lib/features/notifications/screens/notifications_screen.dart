import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/driver_notification.dart';
import '../../../data/repositories/driver_notification_repository.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/profile_setup_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = DriverNotificationRepository();
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _deleting = false;

  Future<void> _markAllRead() async {
    try {
      await _repository.markAllAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'All notifications marked read',
              'Toutes les notifications ont été marquées comme lues',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t('Error: $error', 'Erreur : $error'),
          ),
        ),
      );
    }
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
        title: Text(l.t('Delete notifications?', 'Supprimer les notifications ?')),
        content: Text(
          l.t(
            'This will remove $count notification(s). This cannot be undone.',
            'Cela supprimera $count notification(s). Cette action est irréversible.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.t('Cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.t('Delete', 'Supprimer')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _repository.deleteNotifications(_selectedIds);
      if (!mounted) return;
      _exitSelectionMode();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('Error: $error', 'Erreur : $error')),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DriverProfile>(
    valueListenable: DriverProfileService.instance.profile,
    builder: (context, profile, _) => StreamBuilder<List<DriverNotification>>(
      stream: _repository.watchNotifications(),
      builder: (context, snapshot) {
        final l = DriverCopy.of(context);
        final notifications = snapshot.data ?? const <DriverNotification>[];
        final showSetupReminder =
            profile.verificationStatus != DriverVerificationStatus.approved;
        return FeatureScaffold(
          bottomNavIndex: 4,
          title: _selectionMode
              ? l.t('${_selectedIds.length} selected', '${_selectedIds.length} sélectionnée(s)')
              : l.notifications,
          actions: notifications.isEmpty
              ? null
              : [
                  TextButton(
                    onPressed: _selectionMode ? _exitSelectionMode : () => setState(() => _selectionMode = true),
                    child: Text(_selectionMode ? l.t('Cancel', 'Annuler') : l.t('Select', 'Sélectionner')),
                  ),
                ],
          children: [
            if (showSetupReminder && !_selectionMode) ...[
              ProfileSetupCard(profile: profile),
              const SizedBox(height: 14),
            ],
            if (snapshot.connectionState == ConnectionState.waiting)
              Center(child: CircularProgressIndicator())
            else if (notifications.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Text(
                    showSetupReminder
                        ? l.t('No other notifications.', 'Aucune autre notification.')
                        : l.t('No notifications yet.', 'Aucune notification pour le moment.'),
                  ),
                ),
              )
            else ...[
              // Each notification gets its own tinted-surface-plus-accent-border card when
              // unread (was one shared card with plain ListTiles separated by thin dividers,
              // read and unread rows differing only by title weight and a tiny trailing dot) -
              // matching the Fleet App's notification center (_CompactNotificationRow), so an
              // unread notification is identifiable at a glance, not just on close reading.
              for (final notification in notifications) ...[
                _DriverNotificationRow(
                  notification: notification,
                  icon: _icon(notification.type),
                  color: _color(notification.type),
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(notification.id),
                  onTap: _selectionMode
                      ? () => _toggleSelection(notification.id)
                      : notification.isRead
                      ? null
                      : () => _repository.markAsRead(notification.id),
                  onLongPress: _selectionMode
                      ? null
                      : () {
                          setState(() => _selectionMode = true);
                          _toggleSelection(notification.id);
                        },
                ),
                const SizedBox(height: 9),
              ],
              SizedBox(height: 11),
              if (_selectionMode) ...[
                FilledButton.icon(
                  onPressed: _selectedIds.isEmpty || _deleting ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _deleting
                        ? l.t('Deleting...', 'Suppression...')
                        : l.t('Delete (${_selectedIds.length})', 'Supprimer (${_selectedIds.length})'),
                  ),
                ),
              ] else
                AppOutlineButton(
                  label: l.t('Mark all as read', 'Tout marquer comme lu'),
                  onPressed: _markAllRead,
                ),
            ],
          ],
        );
      },
    ),
  );

  IconData _icon(String type) => switch (type) {
    'ride' => Icons.directions_car_rounded,
    'earning' => Icons.account_balance_wallet_rounded,
    'summary' => Icons.calendar_month_rounded,
    'tip' => Icons.lightbulb_outline_rounded,
    'promotion' => Icons.star_rounded,
    'DRIVER_EARNINGS_CREDITED' => Icons.payments_rounded,
    'DRIVER_PAYOUT_REQUESTED' ||
    'DRIVER_PAYMENT_REQUEST_SUBMITTED' => Icons.hourglass_top_rounded,
    'DRIVER_PAYOUT_PAID' ||
    'DRIVER_PAYMENT_REQUEST_PAID' => Icons.check_circle_rounded,
    'DRIVER_PAYOUT_REJECTED' ||
    'DRIVER_PAYMENT_REQUEST_REJECTED' => Icons.cancel_rounded,
    'DRIVER_PAYMENT_REQUEST_APPROVED' => Icons.thumb_up_alt_rounded,
    'DRIVER_FLEET_REPORT' => Icons.flag_rounded,
    'DRIVER_SUSPENDED' => Icons.block_flipped,
    'DRIVER_SUSPENSION_APPEAL_DECIDED' => Icons.gavel_rounded,
    'DRIVER_RATING_RECEIVED' => Icons.star_rounded,
    'RIDE_CANCELLED_BY_RIDER' ||
    'RIDE_REQUEST_CANCELLED' => Icons.directions_car_filled_outlined,
    'ROAD_ALERT' => Icons.warning_amber_rounded,
    _ => Icons.system_update_rounded,
  };

  Color _color(String type) => switch (type) {
    'earning' ||
    'DRIVER_EARNINGS_CREDITED' ||
    'DRIVER_PAYOUT_PAID' ||
    'DRIVER_PAYMENT_REQUEST_PAID' ||
    'DRIVER_PAYMENT_REQUEST_APPROVED' => AppColors.success,
    'DRIVER_RATING_RECEIVED' => AppColors.warning,
    'promotion' => AppColors.warning,
    'tip' => AppColors.purple,
    'DRIVER_SUSPENDED' ||
    'DRIVER_PAYOUT_REJECTED' ||
    'DRIVER_PAYMENT_REQUEST_REJECTED' ||
    'DRIVER_FLEET_REPORT' ||
    'RIDE_CANCELLED_BY_RIDER' ||
    'RIDE_REQUEST_CANCELLED' => AppColors.danger,
    'ROAD_ALERT' => AppColors.warning,
    _ => AppColors.primary,
  };
}

class _DriverNotificationRow extends StatelessWidget {
  const _DriverNotificationRow({
    required this.notification,
    required this.icon,
    required this.color,
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final DriverNotification notification;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      color: selected ? color.withValues(alpha: .14) : (isRead ? null : color.withValues(alpha: .08)),
      borderColor: selected ? color : (isRead ? null : color.withValues(alpha: .45)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode) ...[
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? color : AppColors.textSecondaryFor(context),
            ),
            const SizedBox(width: 10),
          ],
          IconWell(icon: icon, color: color, background: color.withValues(alpha: .1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 13,
                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMM, hh:mm a').format(notification.createdAt),
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isRead) ...[
                const SizedBox(height: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}
