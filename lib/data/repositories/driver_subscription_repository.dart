import '../models/driver_subscription.dart';

class DriverSubscriptionRepository {
  Future<DriverSubscription> getSubscription() async => DriverSubscription(
    id: 'subscription-001',
    driverId: 'driver-001',
    planName: 'Premium',
    price: 2000,
    isActive: true,
    startedAt: DateTime(2026, 5, 20),
    validUntil: DateTime(2026, 6, 20),
    benefits: const [
      'Lower commission',
      'Priority support',
      'Higher earning opportunities',
      'Exclusive offers',
    ],
  );
}
