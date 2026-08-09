import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/utils/legal_links.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
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
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _changePassword() async {
    final email = DriverProfileService.instance.profile.value.email;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an email address to your profile first.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Text(
          'Send a password reset link to $email? Use the link to set a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService.instance.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset link: $error')),
      );
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

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
              onTap: _changePassword,
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: LegalLinks.openPrivacy,
            ),
            const Divider(height: 1),
            MenuTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: LegalLinks.openTerms,
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
            // Language/theme switching has no real backing yet (this app has no .arb-based
            // localization or a theme-mode controller) - shown as a clear "coming soon" tap
            // response rather than a dropdown/switch that silently does nothing, matching the
            // Export button's convention on the Earnings screen.
            MenuTile(
              icon: Icons.language_rounded,
              title: 'Language',
              trailing: const Text('English'),
              onTap: () => _comingSoon('Language selection'),
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
              onTap: () => _comingSoon('Dark mode'),
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
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'TheRain Driver',
                applicationVersion: _version.isEmpty ? null : _version,
                applicationLegalese: '© TheRain Platform, Cameroon.',
              ),
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
      Text(
        _version.isEmpty ? 'TheRain Driver' : 'TheRain Driver v$_version',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}
