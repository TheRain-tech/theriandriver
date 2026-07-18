/// Canonical Phase 5 driver taxonomy values - region, affiliation, service types, vehicle
/// category. Values (never labels) match
/// therainAdmin/docs/platform/contracts/region-registry.json,
/// driver-affiliations.json, service-types.json, and vehicle-categories.json exactly. Do not
/// invent a second, locally-defined list - see theraindriver/AGENTS.md's regionId note.
class TaxonomyOption {
  const TaxonomyOption(this.value, this.label);

  final String value;
  final String label;
}

abstract final class DriverTaxonomy {
  static const regions = <TaxonomyOption>[
    TaxonomyOption('adamawa', 'Adamawa'),
    TaxonomyOption('centre', 'Centre'),
    TaxonomyOption('east', 'East'),
    TaxonomyOption('far-north', 'Far North'),
    TaxonomyOption('littoral', 'Littoral'),
    TaxonomyOption('north', 'North'),
    TaxonomyOption('northwest', 'North West'),
    TaxonomyOption('west', 'West'),
    TaxonomyOption('south', 'South'),
    TaxonomyOption('southwest', 'South West'),
  ];

  static const affiliations = <TaxonomyOption>[
    TaxonomyOption('independent', 'Independent Driver'),
    TaxonomyOption('therain_managed', 'TheRain-managed Driver'),
    TaxonomyOption('fleet', 'Fleet Driver'),
  ];

  static const affiliationDescriptions = <String, String>{
    'independent':
        'You operate on your own. You own or manage your vehicle and keep the full fare, minus TheRain\'s standard commission.',
    'therain_managed':
        'You drive as part of TheRain\'s own managed driver pool. TheRain assigns and administers your operating terms directly.',
    'fleet':
        'You drive for an approved Fleet company. The Fleet assigns your vehicle and manages your account; you must be invited or request to join one.',
  };

  static const serviceTypes = <TaxonomyOption>[
    TaxonomyOption('ride_hailing', 'Ride hailing'),
    TaxonomyOption('delivery', 'Delivery'),
  ];

  static const vehicleCategories = <TaxonomyOption>[
    TaxonomyOption('motorbike', 'Motorbike'),
    TaxonomyOption('tricycle', 'Tricycle'),
    TaxonomyOption('car', 'Car'),
    TaxonomyOption('suv', 'SUV'),
    TaxonomyOption('van', 'Van'),
    TaxonomyOption('mini_truck', 'Mini Truck / K-Truck'),
    TaxonomyOption('truck', 'Truck'),
  ];

  static String labelFor(List<TaxonomyOption> options, String? value) {
    if (value == null) return '';
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }
}
