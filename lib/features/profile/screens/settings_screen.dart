import 'package:theraindriver/core/localization/driver_copy.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/utils/legal_links.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_preferences_service.dart';
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

  Future<void> _chooseLanguage(DriverCopy copy) async {
    final locale = await showDialog<Locale>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.chooseLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(copy.english),
              onTap: () => Navigator.pop(context, const Locale('en')),
            ),
            ListTile(
              title: Text(copy.french),
              onTap: () => Navigator.pop(context, const Locale('fr')),
            ),
          ],
        ),
      ),
    );
    if (locale != null) {
      await DriverPreferencesService.instance.setLocale(locale);
    }
  }

  Future<void> _chooseTheme(DriverCopy copy) async {
    final themeMode = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.chooseTheme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(copy.light),
              onTap: () => Navigator.pop(context, ThemeMode.light),
            ),
            ListTile(
              title: Text(copy.dark),
              onTap: () => Navigator.pop(context, ThemeMode.dark),
            ),
            ListTile(
              title: Text(copy.systemDefault),
              onTap: () => Navigator.pop(context, ThemeMode.system),
            ),
          ],
        ),
      ),
    );
    if (themeMode != null) {
      await DriverPreferencesService.instance.setThemeMode(themeMode);
    }
  }

  String _themeLabel(DriverCopy copy, ThemeMode themeMode) =>
      switch (themeMode) {
        ThemeMode.dark => copy.dark,
        ThemeMode.system => copy.systemDefault,
        ThemeMode.light => copy.light,
      };

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<DriverAppPreferences>(
    valueListenable: DriverPreferencesService.instance.preferences,
    builder: (context, preferences, _) {
      final copy = DriverCopy.of(context);
      return FeatureScaffold(
        title: copy.settings,
        children: [
          SectionHeader(title: copy.account),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.person_outline_rounded,
                  title: copy.personalInformation,
                  onTap: () =>
                      Navigator.pushNamed(context, RouteNames.editProfile),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.lock_outline_rounded,
                  title: copy.changePassword,
                  onTap: _changePassword,
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: copy.privacyPolicy,
                  onTap: LegalLinks.openPrivacy,
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.description_outlined,
                  title: copy.termsOfService,
                  onTap: LegalLinks.openTerms,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: copy.preferences),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.language_rounded,
                  title: copy.language,
                  trailing: Text(
                    preferences.locale.languageCode == 'fr'
                        ? copy.french
                        : copy.english,
                  ),
                  onTap: () => _chooseLanguage(copy),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.notifications_outlined,
                  title: copy.rideAlerts,
                  trailing: Switch(
                    value: preferences.rideAlertsEnabled,
                    onChanged:
                        DriverPreferencesService.instance.setRideAlertsEnabled,
                  ),
                  onTap: () => DriverPreferencesService.instance
                      .setRideAlertsEnabled(!preferences.rideAlertsEnabled),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.light_mode_outlined,
                  title: copy.appTheme,
                  trailing: Text(_themeLabel(copy, preferences.themeMode)),
                  onTap: () => _chooseTheme(copy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: copy.support),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.help_outline_rounded,
                  title: copy.helpCenter,
                  onTap: () =>
                      Navigator.pushNamed(context, RouteNames.helpCenter),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.info_outline_rounded,
                  title: copy.aboutDriver,
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
                  title: copy.logout,
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
    },
  );
}
