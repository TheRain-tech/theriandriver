import 'package:flutter/material.dart';

import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/menu_tile.dart';
import '../../shared/widgets/search_filter_bar.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only Safety & Security is wired here - it's the one topic this task
    // needs functional (feeds the real incident/Trust & Safety system via
    // SafetyReportScreen). The other 5 topics are left exactly as they were
    // (Help Center's existing topic list, unchanged) rather than scope-creeping
    // into topics this task never asked for.
    final topics = [
      (Icons.person_outline_rounded, 'Account & Verification', null),
      (Icons.account_balance_wallet_outlined, 'Earnings & Payments', null),
      (Icons.route_outlined, 'Trips & Navigation', null),
      (Icons.phone_android_outlined, 'App Issues', null),
      (Icons.group_outlined, 'Rider Issues', null),
      (
        Icons.shield_outlined,
        'Safety & Security',
        () => Navigator.pushNamed(context, RouteNames.safetyReport),
      ),
    ];
    return FeatureScaffold(
      title: 'Help Center',
      children: [
        Text(
          'How can we help you?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const SearchFilterBar(hint: 'Search for help'),
        const SizedBox(height: 18),
        // Easy access to the real SOS/emergency pipeline (signals Central
        // Command, auto-attaches the vehicle camera) directly from Help
        // Center, per the fleet app's SOS Alerts screen this mirrors -
        // Help Center's own topic list below is unchanged.
        AppCard(
          color: AppColors.dangerSoft,
          borderColor: const Color(0xFFFFBEC3),
          onTap: () => Navigator.pushNamed(context, RouteNames.emergency),
          child: const Row(
            children: [
              IconWell(
                icon: Icons.sos_rounded,
                color: AppColors.danger,
                background: Color(0x1AFF3B30),
                size: 52,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('Signal emergency, call fleet/police, share location'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Popular Topics'),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < topics.length; i++) ...[
                MenuTile(
                  icon: topics[i].$1,
                  title: topics[i].$2,
                  onTap: topics[i].$3 ?? () {},
                ),
                if (i < topics.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          color: AppColors.primarySoft,
          onTap: () => Navigator.pushNamed(context, RouteNames.contactSupport),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Still need help?',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('Chat with Support\nWe are here 24/7'),
                  ],
                ),
              ),
              IconWell(icon: Icons.chat_rounded, size: 52),
            ],
          ),
        ),
      ],
    );
  }
}
