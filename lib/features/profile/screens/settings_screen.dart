import 'package:flutter/material.dart';

import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/menu_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Settings',
    children: [
      const SectionHeader(title: 'Account'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            MenuTile(
              icon: Icons.person_outline_rounded,
              title: 'Personal Information',
              onTap: () => Navigator.pushNamed(context, RouteNames.editProfile),
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              onTap: () {},
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              onTap: () {},
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SectionHeader(title: 'Preferences'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            MenuTile(
              icon: Icons.language_rounded,
              title: 'Language',
              trailing: const Text('English'),
              onTap: () {},
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              trailing: Switch(
                value: _notifications,
                onChanged: (value) => setState(() => _notifications = value),
              ),
              onTap: () => setState(() => _notifications = !_notifications),
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.light_mode_outlined,
              title: 'App Theme',
              trailing: const Text('Light'),
              onTap: () {},
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SectionHeader(title: 'Support'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            MenuTile(
              icon: Icons.help_outline_rounded,
              title: 'Help Center',
              onTap: () => Navigator.pushNamed(context, RouteNames.helpCenter),
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.info_outline_rounded,
              title: 'About TheRain Driver',
              onTap: () {},
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.logout_rounded,
              title: 'Logout',
              danger: true,
              onTap: () async {
                try {
                  await AuthService.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    RouteNames.login,
                    (route) => false,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not log out: $error')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'TheRain Driver v1.0.0',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}
