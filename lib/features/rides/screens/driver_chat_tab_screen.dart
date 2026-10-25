import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/chat_unread_count_service.dart';
import '../../../services/trip_service.dart';
import '../../shared/widgets/feature_templates.dart';
import 'ride_chat_screen.dart';

/// Bottom-nav Chat tab. A driver only ever has one active ride at a time
/// (TripService.instance.activeTrip), so this just opens that ride's real
/// chat (ride_chat_screen.dart) rather than maintaining a separate inbox.
class DriverChatTabScreen extends StatelessWidget {
  const DriverChatTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return FeatureScaffold(
      title: copy.chat,
      showBack: false,
      bottomNavIndex: 2,
      children: [
        ValueListenableBuilder(
          valueListenable: TripService.instance.activeTrip,
          builder: (context, trip, _) {
            if (trip == null) {
              return EmptyState(
                title: copy.noActiveTripChatTitle,
                message: copy.noActiveTripChatMessage,
                icon: Icons.chat_bubble_outline_rounded,
              );
            }
            return Column(
              children: [
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideChatScreen(rideId: trip.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        child: Icon(Icons.person_rounded),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.riderName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SizedBox(height: 4),
                            StreamBuilder<int>(
                              stream: watchRideChatUnreadCount(trip.id),
                              builder: (context, snapshot) {
                                final unread = snapshot.data ?? 0;
                                return Text(
                                  unread > 0
                                      ? copy.t(
                                          '$unread unread message${unread == 1 ? '' : 's'}',
                                          '$unread message${unread == 1 ? '' : 's'} non lu${unread == 1 ? '' : 's'}',
                                        )
                                      : copy.t('Tap to chat', 'Touchez pour discuter'),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                PrimaryButton(
                  label: copy.openChatWithRider,
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideChatScreen(rideId: trip.id),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
