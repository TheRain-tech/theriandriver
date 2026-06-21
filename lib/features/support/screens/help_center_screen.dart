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
    const topics = [
      (Icons.person_outline_rounded, 'Account & Verification'),
      (Icons.account_balance_wallet_outlined, 'Earnings & Payments'),
      (Icons.route_outlined, 'Trips & Navigation'),
      (Icons.phone_android_outlined, 'App Issues'),
      (Icons.group_outlined, 'Rider Issues'),
      (Icons.shield_outlined, 'Safety & Security'),
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
        const SizedBox(height: 22),
        const SectionHeader(title: 'Popular Topics'),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < topics.length; i++) ...[
                MenuTile(icon: topics[i].$1, title: topics[i].$2, onTap: () {}),
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
