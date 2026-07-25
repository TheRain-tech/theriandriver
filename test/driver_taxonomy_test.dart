import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/driver_taxonomy.dart';

void main() {
  test(
    'DriverTaxonomy region/affiliation/service/vehicle lists match canonical value counts',
    () {
      expect(DriverTaxonomy.regions.length, 10);
      expect(DriverTaxonomy.affiliations.length, 3);
      expect(DriverTaxonomy.serviceTypes.length, 2);
      expect(DriverTaxonomy.vehicleCategories.length, 7);
    },
  );

  test('DriverTaxonomy.labelFor resolves a known value to its label', () {
    expect(
      DriverTaxonomy.labelFor(DriverTaxonomy.regions, 'northwest'),
      'North West',
    );
    expect(
      DriverTaxonomy.labelFor(DriverTaxonomy.affiliations, 'fleet'),
      'Fleet Driver',
    );
  });

  test(
    'DriverTaxonomy.labelFor falls back to the raw value for an unrecognized one',
    () {
      expect(
        DriverTaxonomy.labelFor(DriverTaxonomy.regions, 'atlantis'),
        'atlantis',
      );
    },
  );

  test('DriverTaxonomy.labelFor returns empty string for null', () {
    expect(DriverTaxonomy.labelFor(DriverTaxonomy.regions, null), '');
  });

  test('every affiliation option has a description', () {
    for (final option in DriverTaxonomy.affiliations) {
      expect(DriverTaxonomy.affiliationDescriptions[option.value], isNotNull);
    }
  });
}
