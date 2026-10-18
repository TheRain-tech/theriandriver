import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../data/models/driver_trip.dart';
import '../../../services/chat_unread_count_service.dart';
import '../../../theme/app_colors.dart';
import '../screens/ride_chat_screen.dart';

/// Call and Chat as floating circular buttons over the live tracking map, mirroring the Rider
/// app's own FloatingTripControls - was previously an inline call icon on RiderCard plus a
/// separate full-width "Chat with Rider" button inside the scrollable pickup sheet, both of
/// which could be scrolled out of view.
class DriverFloatingTripControls extends StatelessWidget {
  const DriverFloatingTripControls({super.key, required this.trip});

  final DriverTrip trip;

  Future<void> _call(BuildContext context) async {
    final phone = trip.riderPhone;
    if (phone.isEmpty) return;
    final copy = DriverCopy.of(context);
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: phone.trim()),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy.t(
              'No calling app is available on this device.',
              "Aucune application d'appel n'est disponible sur cet appareil.",
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy.t(
              'Could not open rider contact. Please try again.',
              "Impossible d'ouvrir le contact du passager. Veuillez réessayer.",
            ),
          ),
        ),
      );
    }
  }

  void _openChat(BuildContext context) {
    if (trip.id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RideChatScreen(rideId: trip.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: watchRideChatUnreadCount(trip.id),
      builder: (context, unreadSnapshot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FloatingCircleButton(
              icon: Icons.chat_bubble_rounded,
              badgeCount: unreadSnapshot.data ?? 0,
              tooltip: DriverCopy.of(context).chat,
              onTap: trip.id.isEmpty ? null : () => _openChat(context),
            ),
            const SizedBox(height: 12),
            _FloatingCircleButton(
              icon: Icons.phone_rounded,
              tooltip: DriverCopy.of(context).t('Call', 'Appeler'),
              onTap: trip.riderPhone.isEmpty ? null : () => _call(context),
            ),
          ],
        );
      },
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceFor(context),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x330A1A33),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Badge.count(
              count: badgeCount,
              isLabelVisible: badgeCount > 0,
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
