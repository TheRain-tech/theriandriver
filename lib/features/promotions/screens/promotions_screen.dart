import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
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
      final copy = DriverCopy.of(context);
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Scaffold(
          body: LoadingState(
            label: copy.t('Loading promotions...', 'Chargement des promotions...'),
          ),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: ErrorState(
            message: copy.t(
              'Could not load active promotions. Please try again.',
              'Impossible de charger les promotions actives. Veuillez réessayer.',
            ),
            onRetry: _retry,
          ),
        );
      }
      final promotions = snapshot.data ?? const <DriverPromotion>[];

      if (promotions.isEmpty) {
        return Scaffold(
          body: FeatureScaffold(
            title: copy.t('Promotions', 'Promotions'),
            children: [
              SizedBox(height: 40),
              EmptyState(
                title: copy.t('No Promotions Available', 'Aucune promotion disponible'),
                message: copy.t(
                  'Check back later for active promotions and earning bonuses.',
                  'Revenez plus tard pour découvrir les promotions actives et les bonus de gains.',
                ),
                icon: Icons.local_offer_outlined,
              ),
              SizedBox(height: 20),
              AppOutlineButton(
                label: copy.t('Refresh', 'Actualiser'),
                onPressed: _retry,
              ),
            ],
          ),
        );
      }

      final primaryPromo = promotions.first;

      return Scaffold(
        body: FeatureScaffold(
          title: copy.t('Promotions', 'Promotions'),
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
                                StatusBadge(label: copy.t('Active', 'Active')),
                                SizedBox(height: 12),
                                Text(
                                  primaryPromo.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  primaryPromo.description,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.white,
                            size: 74,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    SectionHeader(
                      title: copy.t(
                        'Available Promotions',
                        'Promotions disponibles',
                      ),
                    ),
                    SizedBox(height: 8),
                    for (final promotion in promotions.skip(1)) ...[
                      AppCard(
                        child: Row(
                          children: [
                            IconWell(icon: Icons.local_offer_outlined),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    promotion.title,
                                    style: TextStyle(
                                      color: AppColors.textPrimaryFor(context),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(promotion.description),
                                  Text(
                                    copy.t(
                                      'Up to ${CurrencyFormatter.format(promotion.reward)}',
                                      "Jusqu'à ${CurrencyFormatter.format(promotion.reward)}",
                                    ),
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(label: copy.t('Active', 'Active')),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                    SizedBox(height: 10),
                    AppOutlineButton(
                      label: copy.t(
                        'Refresh Promotions List',
                        'Actualiser la liste des promotions',
                      ),
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
