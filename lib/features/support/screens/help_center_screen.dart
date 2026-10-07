import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/menu_tile.dart';
import '../../shared/widgets/search_filter_bar.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    // Only Safety & Security is wired here - it's the one topic this task
    // needs functional (feeds the real incident/Trust & Safety system via
    // SafetyReportScreen). The other 5 topics are left exactly as they were
    // (Help Center's existing topic list, unchanged) rather than scope-creeping
    // into topics this task never asked for.
    final topics = [
      (Icons.person_outline_rounded, l.t('Account & Verification', 'Compte et vérification'), null),
      (Icons.account_balance_wallet_outlined, l.t('Earnings & Payments', 'Revenus et paiements'), null),
      (Icons.route_outlined, l.t('Trips & Navigation', 'Courses et navigation'), null),
      (Icons.phone_android_outlined, l.t('App Issues', 'Problèmes d\'application'), null),
      (Icons.group_outlined, l.t('Rider Issues', 'Problèmes avec les passagers'), null),
      (
        Icons.shield_outlined,
        l.t('Safety & Security', 'Sécurité'),
        () => Navigator.pushNamed(context, RouteNames.safetyReport),
      ),
    ];
    return FeatureScaffold(
      title: l.t('Help Center', 'Centre d\'aide'),
      children: [
        Text(
          l.t('How can we help you?', 'Comment pouvons-nous vous aider ?'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 12),
        SearchFilterBar(hint: l.t('Search for help', 'Rechercher de l\'aide')),
        const SizedBox(height: 18),
        // Easy access to the real SOS/emergency pipeline (signals Central
        // Command, auto-attaches the vehicle camera) directly from Help
        // Center, per the fleet app's SOS Alerts screen this mirrors -
        // Help Center's own topic list below is unchanged.
        AppCard(
          color: AppColors.dangerSoftFor(context),
          borderColor: const Color(0xFFFFBEC3),
          onTap: () => Navigator.pushNamed(context, RouteNames.emergency),
          child: Row(
            children: [
              const IconWell(
                icon: Icons.sos_rounded,
                color: AppColors.danger,
                background: Color(0x1AFF3B30),
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('Emergency', 'Urgence'),
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l.t(
                        'Signal emergency, call fleet/police, share location',
                        'Signaler une urgence, appeler la flotte/police, partager la position',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionHeader(title: l.t('Popular Topics', 'Sujets populaires')),
        SizedBox(height: 8),
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
        SizedBox(height: 18),
        AppCard(
          color: AppColors.primarySoftFor(context),
          onTap: () => Navigator.pushNamed(context, RouteNames.contactSupport),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('Still need help?', 'Besoin d\'aide supplémentaire ?'),
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l.t(
                        'Chat with Support\nWe are here 24/7',
                        'Discutez avec le support\nNous sommes là 24h/24 et 7j/7',
                      ),
                    ),
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
