import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/services/vehicle_marker_factory.dart';

void main() {
  group('theRainVehicleKindFor', () {
    test('maps the established car service tiers to the car artwork', () {
      for (final value in ['classic', 'comfort', 'VIP', 'xl', 'sedan']) {
        expect(theRainVehicleKindFor(value), TheRainVehicleKind.car);
      }
    });

    test('maps the approved non-car vehicle families', () {
      expect(theRainVehicleKindFor('bike'), TheRainVehicleKind.bike);
      expect(
        theRainVehicleKindFor('delivery-van'),
        TheRainVehicleKind.delivery,
      );
      expect(theRainVehicleKindFor('school bus'), TheRainVehicleKind.school);
    });

    test('does not replace missing backend data with a guessed vehicle', () {
      expect(theRainVehicleKindFor(null), isNull);
      expect(theRainVehicleKindFor('helicopter'), isNull);
    });
  });
}
