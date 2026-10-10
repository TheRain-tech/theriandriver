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
        final showSetupReminder =
            profile.verificationStatus != DriverVerificationStatus.approved;
        return FeatureScaffold(
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
                  onTap: notification.isRead
                      ? null
                      : () => _repository.markAsRead(notification.id),
                ),
                const SizedBox(height: 9),
              ],
              SizedBox(height: 11),
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
  });

  final DriverNotification notification;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      color: isRead ? null : color.withValues(alpha: .08),
      borderColor: isRead ? null : color.withValues(alpha: .45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    );
  }
}
