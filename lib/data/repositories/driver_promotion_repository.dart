import '../mock/mock_driver_promotions.dart';
import '../models/driver_promotion.dart';

class DriverPromotionRepository {
  Future<List<DriverPromotion>> getPromotions() async =>
      List.unmodifiable(mockDriverPromotions);
}
