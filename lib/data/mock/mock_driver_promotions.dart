import '../models/driver_promotion.dart';

final mockDriverPromotions = <DriverPromotion>[
  DriverPromotion(
    id: 'promo-001',
    title: 'Weekend Bonus',
    description: 'Earn 20% more on every trip this weekend.',
    reward: 5000,
    startsAt: DateTime(2026, 6, 6),
    endsAt: DateTime(2026, 6, 8),
    isActive: true,
  ),
  DriverPromotion(
    id: 'promo-002',
    title: 'Peak Hours Bonus',
    description: 'Earn extra during rush hours.',
    reward: 2500,
    startsAt: DateTime(2026, 6, 1),
    endsAt: DateTime(2026, 6, 30),
    isActive: true,
  ),
  DriverPromotion(
    id: 'promo-003',
    title: 'Refer a Driver',
    description: 'Invite friends and earn 3,000 XAF.',
    reward: 3000,
    startsAt: DateTime(2026, 1, 1),
    endsAt: DateTime(2026, 12, 31),
    isActive: true,
  ),
  DriverPromotion(
    id: 'promo-004',
    title: 'Top Driver Challenge',
    description: 'Complete 60 trips this week.',
    reward: 10000,
    startsAt: DateTime(2026, 6, 1),
    endsAt: DateTime(2026, 6, 8),
    isActive: true,
  ),
];
