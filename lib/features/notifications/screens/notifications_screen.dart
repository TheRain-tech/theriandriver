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
  bool _deletingAll = false;
  final Set<String> _selectedIds = <String>{};

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<bool> _confirmDeletion({
    required String title,
    required String body,
  }) async {
    final copy = DriverCopy.current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.t('Cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.t('Delete', 'Supprimer')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<bool> _deleteNotification(String id) async {
    final copy = DriverCopy.current;
    final confirmed = await _confirmDeletion(
      title: copy.t('Delete this notification?', 'Supprimer cette notification ?'),
      body: copy.t('This cannot be undone.', 'Cette action est irréversible.'),
    );
    if (!confirmed || !mounted) return false;
    try {
      await _repository.deleteNotification(id);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Unable to delete this notification: $error',
              'Impossible de supprimer cette notification : $error',
            ),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _deleteAll() async {
    final copy = DriverCopy.current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          copy.t('Delete all notifications?', 'Supprimer toutes les notifications ?'),
        ),
        content: Text(
          copy.t('This cannot be undone.', 'Cette action est irréversible.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.t('Cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.t('Delete all', 'Tout supprimer')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingAll = true);
    try {
      await _repository.deleteAllNotifications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Unable to delete notifications: $error',
              'Impossible de supprimer les notifications : $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAll = false);
    }
  }

  Future<void> _deleteSelected(Set<String> selectedIds) async {
    final ids = selectedIds.toList(growable: false);
    if (ids.isEmpty || _deletingAll) return;
    final copy = DriverCopy.current;
    final confirmed = await _confirmDeletion(
      title: copy.t(
        'Delete the selected notifications?',
        'Supprimer les notifications sélectionnées ?',
      ),
      body: copy.t('This cannot be undone.', 'Cette action est irréversible.'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _deletingAll = true);
    try {
      await _repository.deleteNotifications(ids);
      if (mounted) setState(_selectedIds.clear);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Unable to delete selected notifications: $error',
              'Impossible de supprimer les notifications sélectionnées : $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAll = false);
    }
  }

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

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DriverProfile>(
    valueListenable: DriverProfileService.instance.profile,
    builder: (context, profile, _) => StreamBuilder<List<DriverNotification>>(
      stream: _repository.watchNotifications(),
      builder: (context, snapshot) {
        final l = DriverCopy.of(context);
        final notifications = snapshot.data ?? const <DriverNotification>[];
        final visibleIds = notifications.map((item) => item.id).toSet();
        final selectedIds = _selectedIds.intersection(visibleIds);
        final showSetupReminder =
            profile.verificationStatus != DriverVerificationStatus.approved;
        return FeatureScaffold(
          bottomNavIndex: 4,
          title: l.notifications,
          children: [
            if (showSetupReminder) ...[
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
                        ? l.t(
                            'No other notifications.',
                            'Aucune autre notification.',
                          )
                        : l.t(
                            'No notifications yet.',
                            'Aucune notification pour le moment.',
                          ),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: AppOutlineButton(
                      label: selectedIds.length == notifications.length
                          ? l.t('Deselect all', 'Tout désélectionner')
                          : l.t('Select all', 'Tout sélectionner'),
                      onPressed: () => setState(() {
                        if (selectedIds.length == notifications.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds
                            ..clear()
                            ..addAll(notifications.map((item) => item.id));
                        }
                      }),
                    ),
                  ),
                  if (selectedIds.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppOutlineButton(
                        label: _deletingAll
                            ? l.t('Deleting...', 'Suppression...')
                            : l.t(
                                'Delete selected (${selectedIds.length})',
                                'Supprimer la sélection (${selectedIds.length})',
                              ),
                        onPressed: _deletingAll
                            ? null
                            : () => _deleteSelected(selectedIds),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Each notification gets its own tinted-surface-plus-accent-border card when
              // unread (was one shared card with plain ListTiles separated by thin dividers,
              // read and unread rows differing only by title weight and a tiny trailing dot) -
              // matching the Fleet App's notification center (_CompactNotificationRow), so an
              // unread notification is identifiable at a glance, not just on close reading.
              for (final notification in notifications) ...[
                Dismissible(
                  key: ValueKey('driver-notification-${notification.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) => _deleteNotification(notification.id),
                  child: _DriverNotificationRow(
                    notification: notification,
                    icon: _icon(notification.type),
                    color: _color(notification.type),
                    selected: selectedIds.contains(notification.id),
                    onDelete: () => _deleteNotification(notification.id),
                    onLongPress: () => _toggleSelection(notification.id),
                    onTap: selectedIds.isNotEmpty
                        ? () => _toggleSelection(notification.id)
                        : notification.isRead
                        ? null
                        : () => _repository.markAsRead(notification.id),
                  ),
                ),
                const SizedBox(height: 9),
              ],
              SizedBox(height: 11),
              AppOutlineButton(
                label: l.t('Mark all as read', 'Tout marquer comme lu'),
                onPressed: _markAllRead,
              ),
              const SizedBox(height: 8),
              AppOutlineButton(
                label: _deletingAll
                    ? l.t('Deleting...', 'Suppression...')
                    : l.t('Delete all notifications', 'Tout supprimer'),
                onPressed: _deletingAll ? null : _deleteAll,
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
    required this.onDelete,
    required this.selected,
    required this.onLongPress,
    this.onTap,
  });

  final DriverNotification notification;
  final IconData icon;
  final Color color;
  final Future<bool> Function() onDelete;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : isRead
            ? null
            : color.withValues(alpha: .08),
        borderColor: selected
            ? Theme.of(context).colorScheme.primary
            : isRead
            ? null
            : color.withValues(alpha: .45),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconWell(
              icon: icon,
              color: color,
              background: color.withValues(alpha: .1),
            ),
            const SizedBox(width: 12),
            if (selected) ...[
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRead) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      tooltip: DriverCopy.of(
                        context,
                      ).t('Delete notification', 'Supprimer la notification'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => onDelete(),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.textSecondaryFor(context),
                      ),
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
