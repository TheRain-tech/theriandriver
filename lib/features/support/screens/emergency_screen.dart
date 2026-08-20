import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/danger_button.dart';
import '../../../data/repositories/sos_repository.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _sharingLocation = false;

  Future<void> _shareLocation() async {
    if (_sharingLocation) return;
    setState(() => _sharingLocation = true);
    try {
      final location =
          LocationService.instance.currentLocation.value ??
          await LocationService.instance.getCurrentLocation();
      await Share.share(
        'I need help! My location: https://maps.google.com/?q=${location.lat},${location.lng}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get your location. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DriverProfileService.instance.profile,
      builder: (context, profile, _) {
        return ValueListenableBuilder(
          valueListenable: DriverProfileService.instance.fleetInfo,
          builder: (context, fleetInfo, _) {
            // A fleet-linked driver's first call should reach their own
            // fleet owner (who already knows their vehicle/route); an
            // independent driver has no fleet to call, so this falls back to
            // the real Cameroon police line instead - never left dead.
            final isFleetDriver =
                profile.fleetId != null && profile.fleetId!.trim().isNotEmpty;
            final fleetPhone = fleetInfo?.phoneNumber?.trim();
            final hasFleetPhone = isFleetDriver &&
                fleetPhone != null &&
                fleetPhone.isNotEmpty;
            final primaryCallLabel = hasFleetPhone
                ? 'Call Fleet'
                : 'Call Police (117)';
            final primaryCallSubtitle = hasFleetPhone
                ? (fleetInfo?.fleetName ?? 'Your fleet owner')
                : 'Cameroon National Police';
            final primaryCallTarget = hasFleetPhone ? fleetPhone : '117';

            final actions = [
              (
                Icons.call_rounded,
                primaryCallLabel,
                primaryCallSubtitle,
                AppColors.danger,
                () => launchUrl(Uri(scheme: 'tel', path: primaryCallTarget)),
              ),
              (
                Icons.location_on_rounded,
                'Share My Location',
                _sharingLocation ? 'Sharing...' : 'Share live location',
                AppColors.success,
                _sharingLocation ? null : _shareLocation,
              ),
              (
                Icons.people_alt_outlined,
                'Trusted Contacts',
                'Notify your contacts',
                AppColors.purple,
                null,
              ),
            ];
            return FeatureScaffold(
              title: 'Emergency',
              children: [
                AppCard(
                  color: AppColors.dangerSoft,
                  borderColor: const Color(0xFFFFBEC3),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.sos_rounded,
                        color: AppColors.danger,
                        size: 64,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Signal Emergency',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Alerts TheRain Central Command and starts recording on your vehicle camera.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      DangerButton(
                        label: 'Signal Emergency',
                        icon: Icons.campaign_rounded,
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) {
                            bool isSending = false;
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return AlertDialog(
                                  title: const Text('Signal emergency?'),
                                  content: const Text(
                                    'This immediately notifies the Super Admin and your Regional Admin, '
                                    'shares your live location, and - if your vehicle has a camera - starts '
                                    'recording and live-streams the incident to TheRain Central Command.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: isSending
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: isSending
                                          ? null
                                          : () async {
                                              setDialogState(
                                                () => isSending = true,
                                              );
                                              try {
                                                await SosRepository()
                                                    .sendSosAlert();
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Emergency signal sent. Central Command has been notified.',
                                                    ),
                                                    backgroundColor:
                                                        AppColors.danger,
                                                  ),
                                                );
                                              } catch (error) {
                                                if (!context.mounted) return;
                                                setDialogState(
                                                  () => isSending = false,
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'We could not send the emergency signal. Please try again or call emergency services directly.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.danger,
                                      ),
                                      child: isSending
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Send Signal'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 8),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          leading: IconWell(
                            icon: actions[i].$1,
                            color: actions[i].$4,
                            background: actions[i].$4.withValues(alpha: .1),
                          ),
                          title: Text(
                            actions[i].$2,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(actions[i].$3),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: actions[i].$5,
                        ),
                        if (i < actions.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Use only in real emergencies.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
