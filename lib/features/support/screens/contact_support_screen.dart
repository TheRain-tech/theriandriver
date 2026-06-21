import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        Icons.chat_bubble_outline_rounded,
        'Live Chat',
        'Chat with our support team',
        AppColors.primary,
        () {},
      ),
      (
        Icons.call_outlined,
        'Call Us',
        '${AppConstants.supportPhone}\nAvailable 24/7',
        AppColors.success,
        () {},
      ),
      (
        Icons.email_outlined,
        'Email Us',
        '${AppConstants.supportEmail}\nWe reply within 24 hours',
        AppColors.primary,
        () {},
      ),
      (
        Icons.report_outlined,
        'Report an Issue',
        'Describe your problem',
        AppColors.warning,
        () => Navigator.pushNamed(context, RouteNames.reportIssue),
      ),
    ];
    return FeatureScaffold(
      title: 'Contact Support',
      subtitle: 'Choose a way to reach us',
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.$2,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(option.$3),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        AppCard(
          onTap: () {},
          child: const Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: 'FAQ',
                  value: 'View frequently asked questions',
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
