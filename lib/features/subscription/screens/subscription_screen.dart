import '../../../core/localization/driver_copy.dart';
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
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final copy = DriverCopy.of(context);
      return FeatureScaffold(
        title: copy.t('Subscription', 'Abonnement'),
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
                Icon(Icons.diamond_rounded, color: Colors.white, size: 58),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.t('Current Plan', 'Forfait actuel'),
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        copy.t(
                          '${subscription.planName} Plan',
                          'Forfait ${subscription.planName}',
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        copy.t(
                          'Valid until ${DateFormatter.short(subscription.validUntil)}',
                          'Valide jusqu\'au ${DateFormatter.short(subscription.validUntil)}',
                        ),
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: copy.t('Active', 'Actif')),
              ],
            ),
          ),
          SizedBox(height: 22),
          SectionHeader(title: copy.t('Plan Benefits', 'Avantages du forfait')),
          SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                for (final benefit in subscription.benefits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            benefit,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
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
          SizedBox(height: 20),
          PrimaryButton(
            label: copy.t('Manage Subscription', "Gérer l'abonnement"),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  DriverCopy.current.t(
                    'Subscription management is coming soon.',
                    "La gestion de l'abonnement sera bientôt disponible.",
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
