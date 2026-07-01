import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_promotion.dart';
import '../../../data/repositories/driver_promotion_repository.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final _repository = DriverPromotionRepository();
  late Future<List<DriverPromotion>> _promotionsFuture;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  void _loadPromotions() {
    _promotionsFuture = _repository.getPromotions();
  }

  void _retry() {
    setState(() {
      _loadPromotions();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DriverPromotion>>(
    future: _promotionsFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: LoadingState(label: 'Loading promotions...'),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: ErrorState(
            message: 'Could not load active promotions. Please try again.',
            onRetry: _retry,
          ),
        );
      }
      final promotions = snapshot.data ?? const <DriverPromotion>[];

      if (promotions.isEmpty) {
        return Scaffold(
          body: FeatureScaffold(
            title: 'Promotions',
            children: [
              const SizedBox(height: 40),
              const EmptyState(
                title: 'No Promotions Available',
                message:
                    'Check back later for active promotions and earning bonuses.',
                icon: Icons.local_offer_outlined,
              ),
              const SizedBox(height: 20),
              AppOutlineButton(label: 'Refresh', onPressed: _retry),
            ],
          ),
        );
      }

      final primaryPromo = promotions.first;

      return Scaffold(
        body: FeatureScaffold(
          title: 'Promotions',
          children: [
            RefreshIndicator(
              onRefresh: () async => _retry(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const StatusBadge(label: 'Active'),
                                const SizedBox(height: 12),
                                Text(
                                  primaryPromo.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  primaryPromo.description,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.white,
                            size: 74,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Available Promotions'),
                    const SizedBox(height: 8),
                    for (final promotion in promotions.skip(1)) ...[
                      AppCard(
                        child: Row(
                          children: [
                            const IconWell(icon: Icons.local_offer_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    promotion.title,
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(promotion.description),
                                  Text(
                                    'Up to ${CurrencyFormatter.format(promotion.reward)}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const StatusBadge(label: 'Active'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    AppOutlineButton(
                      label: 'Refresh Promotions List',
                      onPressed: _retry,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
