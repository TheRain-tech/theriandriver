import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/driver_copy.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    final options = [
      (
        Icons.chat_bubble_outline_rounded,
        l.t('Live Chat', 'Chat en direct'),
        l.t('Chat with our support team', 'Discutez avec notre équipe de support'),
        AppColors.primary,
        () {},
      ),
      (
        Icons.call_outlined,
        l.t('Call Us', 'Appelez-nous'),
        l.t(
          '${AppConstants.supportPhone}\nAvailable 24/7',
          '${AppConstants.supportPhone}\nDisponible 24h/24 et 7j/7',
        ),
        AppColors.success,
        () {},
      ),
      (
        Icons.email_outlined,
        l.t('Email Us', 'Envoyez-nous un e-mail'),
        l.t(
          '${AppConstants.supportEmail}\nWe reply within 24 hours',
          '${AppConstants.supportEmail}\nNous répondons dans les 24 heures',
        ),
        AppColors.primary,
        () {},
      ),
      (
        Icons.report_outlined,
        l.t('Report an Issue', 'Signaler un problème'),
        l.t('Describe your problem', 'Décrivez votre problème'),
        AppColors.warning,
        () => Navigator.pushNamed(context, RouteNames.reportIssue),
      ),
    ];
    return FeatureScaffold(
      title: l.t('Contact Support', 'Contacter le support'),
      subtitle: l.t('Choose a way to reach us', 'Choisissez un moyen de nous contacter'),
      children: [
        for (final option in options) ...[
          AppCard(
            onTap: option.$5,
            child: Row(
              children: [
                IconWell(
                  icon: option.$1,
                  color: option.$4,
                  background: option.$4.withValues(alpha: .1),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.$2,
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(option.$3),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          SizedBox(height: 10),
        ],
        SizedBox(height: 12),
        AppCard(
          onTap: () {},
          child: Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: l.t('FAQ', 'FAQ'),
                  value: l.t('View frequently asked questions', 'Voir les questions fréquemment posées'),
                ),
              ),
              Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ],
    );
  }
}
