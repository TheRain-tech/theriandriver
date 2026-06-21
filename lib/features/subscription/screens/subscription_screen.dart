import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_subscription.dart';
import '../../../data/repositories/driver_subscription_repository.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class SubscriptionScreen extends StatelessWidget {
  SubscriptionScreen({super.key});
  final _repository = DriverSubscriptionRepository();

  @override
  Widget build(BuildContext context) => FutureBuilder<DriverSubscription>(
    future: _repository.getSubscription(),
    builder: (context, snapshot) {
      final subscription = snapshot.data;
      if (subscription == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FeatureScaffold(
        title: 'Subscription',
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.diamond_rounded,
                  color: Colors.white,
                  size: 58,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Plan',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${subscription.planName} Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Valid until ${DateFormatter.short(subscription.validUntil)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const StatusBadge(label: 'Active'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Plan Benefits'),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                for (final benefit in subscription.benefits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            benefit,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Manage Subscription', onPressed: () {}),
        ],
      );
    },
  );
}
