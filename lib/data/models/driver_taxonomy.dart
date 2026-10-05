/// Canonical Phase 5 driver taxonomy values - region, affiliation, service types, vehicle
/// category. Values (never labels) match
/// therainAdmin/docs/platform/contracts/region-registry.json,
/// driver-affiliations.json, service-types.json, and vehicle-categories.json exactly. Do not
/// invent a second, locally-defined list - see theraindriver/AGENTS.md's regionId note.
class TaxonomyOption {
  const TaxonomyOption(this.value, this.label, [String? labelFr])
    : labelFr = labelFr ?? label;

  final String value;
  final String label;
  final String labelFr;

  /// The English `label` is kept as the default for every existing call site
  /// and test (`DriverTaxonomy.labelFor`, `option.label`) - this is the
  /// opt-in locale-aware accessor new UI code should call instead.
  String localizedLabel(bool isFrench) => isFrench ? labelFr : label;
}

abstract final class DriverTaxonomy {
  static const regions = <TaxonomyOption>[
    TaxonomyOption('adamawa', 'Adamawa', 'Adamaoua'),
    TaxonomyOption('centre', 'Centre', 'Centre'),
    TaxonomyOption('east', 'East', 'Est'),
    TaxonomyOption('far-north', 'Far North', 'Extrême-Nord'),
    TaxonomyOption('littoral', 'Littoral', 'Littoral'),
    TaxonomyOption('north', 'North', 'Nord'),
    TaxonomyOption('northwest', 'North West', 'Nord-Ouest'),
    TaxonomyOption('west', 'West', 'Ouest'),
    TaxonomyOption('south', 'South', 'Sud'),
    TaxonomyOption('southwest', 'South West', 'Sud-Ouest'),
  ];

  static const affiliations = <TaxonomyOption>[
    TaxonomyOption(
      'independent',
      'Independent Driver',
      'Chauffeur indépendant',
    ),
    TaxonomyOption(
      'therain_managed',
      'TheRain-managed Driver',
      'Chauffeur géré par TheRain',
    ),
    TaxonomyOption('fleet', 'Fleet Driver', 'Chauffeur de flotte'),
  ];

  static const affiliationDescriptions = <String, String>{
    'independent':
        'You operate on your own. You own or manage your vehicle and keep the full fare, minus TheRain\'s standard commission.',
    'therain_managed':
        'You drive as part of TheRain\'s own managed driver pool. TheRain assigns and administers your operating terms directly.',
    'fleet':
        'You drive for an approved Fleet company. The Fleet assigns your vehicle and manages your account; you must be invited or request to join one.',
  };

  static const affiliationDescriptionsFr = <String, String>{
    'independent':
        'Vous opérez seul. Vous possédez ou gérez votre véhicule et conservez la totalité de la course, moins la commission standard de TheRain.',
    'therain_managed':
        'Vous conduisez au sein du propre parc de chauffeurs géré par TheRain. TheRain attribue et administre directement vos conditions d\'exploitation.',
    'fleet':
        'Vous conduisez pour une entreprise de flotte approuvée. La flotte attribue votre véhicule et gère votre compte ; vous devez être invité ou demander à en rejoindre une.',
  };

  static const serviceTypes = <TaxonomyOption>[
    TaxonomyOption('ride_hailing', 'Ride hailing', 'Transport de passagers'),
    TaxonomyOption('delivery', 'Delivery', 'Livraison'),
    TaxonomyOption('ambulance', 'Ambulance', 'Ambulance'),
  ];

  static const vehicleCategories = <TaxonomyOption>[
    TaxonomyOption('motorbike', 'Motorbike', 'Moto'),
    TaxonomyOption('tricycle', 'Tricycle', 'Tricycle'),
    TaxonomyOption('car', 'Car', 'Voiture'),
    TaxonomyOption('suv', 'SUV', 'SUV'),
    TaxonomyOption('van', 'Van', 'Camionnette'),
    TaxonomyOption(
      'mini_truck',
      'Mini Truck / K-Truck',
      'Mini-camion / K-Truck',
    ),
    TaxonomyOption('truck', 'Truck', 'Camion'),
    TaxonomyOption('ambulance', 'Ambulance', 'Ambulance'),
  ];

  static String labelFor(
    List<TaxonomyOption> options,
    String? value, {
    bool isFrench = false,
  }) {
    if (value == null) return '';
    for (final option in options) {
      if (option.value == value) return option.localizedLabel(isFrench);
    }
    return value;
  }

  static String affiliationDescriptionFor(String? value, {bool isFrench = false}) {
    if (value == null) return '';
    final map = isFrench ? affiliationDescriptionsFr : affiliationDescriptions;
    return map[value] ?? '';
  }
}
