import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/danger_button.dart';
import '../../../data/repositories/sos_repository.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.call_rounded, 'Call 112', 'Emergency services', AppColors.danger),
      (
        Icons.location_on_rounded,
        'Share My Location',
        'Share live location',
        AppColors.success,
      ),
      (
        Icons.people_alt_outlined,
        'Trusted Contacts',
        'Notify your contacts',
        AppColors.purple,
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
              const Icon(Icons.sos_rounded, color: AppColors.danger, size: 64),
              const SizedBox(height: 8),
              const Text(
                'SOS Emergency',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap the button below to alert us in an emergency.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              DangerButton(
                label: 'Send SOS Alert',
                icon: Icons.campaign_rounded,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) {
                    bool isSending = false;
                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        return AlertDialog(
                          title: const Text('Send SOS alert?'),
                          content: const Text(
                            'TheRain safety support and your trusted contacts will be notified.',
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
                                      setDialogState(() => isSending = true);
                                      try {
                                        await SosRepository().sendSosAlert();
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'SOS alert sent. Help has been notified.',
                                            ),
                                            backgroundColor: AppColors.danger,
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        setDialogState(() => isSending = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'We could not send SOS alert. Please try again or call emergency services directly.',
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
                                  : const Text('Send Alert'),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
                  onTap: i == 0
                      ? () => launchUrl(Uri(scheme: 'tel', path: '112'))
                      : null,
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
  }
}
