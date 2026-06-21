import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../data/models/driver_notification.dart';
import '../../../data/repositories/driver_notification_repository.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

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
        const SnackBar(content: Text('All notifications marked read')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<DriverNotification>>(
    stream: _repository.watchNotifications(),
    builder: (context, snapshot) {
      final notifications = snapshot.data ?? const <DriverNotification>[];
      return FeatureScaffold(
        title: 'Notifications',
        children: [
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (notifications.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28.0),
                child: Text('No notifications yet.'),
              ),
            )
          else ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < notifications.length; i++) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: IconWell(
                        icon: _icon(notifications[i].type),
                        color: _color(notifications[i].type),
                        background: _color(
                          notifications[i].type,
                        ).withValues(alpha: .1),
                      ),
                      title: Text(
                        notifications[i].title,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: notifications[i].isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(notifications[i].message),
                      onTap: notifications[i].isRead
                          ? null
                          : () => _repository.markAsRead(notifications[i].id),
                      trailing: Opacity(
                        opacity: notifications[i].isRead ? 0.5 : 1.0,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: notifications[i].isRead
                              ? Colors.transparent
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    if (i < notifications.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppOutlineButton(
              label: 'Mark all as read',
              onPressed: _markAllRead,
            ),
          ],
        ],
      );
    },
  );

  IconData _icon(String type) => switch (type) {
    'ride' => Icons.directions_car_rounded,
    'earning' => Icons.account_balance_wallet_rounded,
    'summary' => Icons.calendar_month_rounded,
    'tip' => Icons.lightbulb_outline_rounded,
    'promotion' => Icons.star_rounded,
    _ => Icons.system_update_rounded,
  };

  Color _color(String type) => switch (type) {
    'earning' => AppColors.success,
    'promotion' => AppColors.warning,
    'tip' => AppColors.purple,
    _ => AppColors.primary,
  };
}
