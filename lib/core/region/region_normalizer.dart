/// Mirrors node-api's utils/region.js#normalizeRegionId exactly, so a
/// driver-typed "City or region" value (e.g. "Bamenda") resolves to the same
/// canonical regionId ("northwest") the admin dashboards and node-api's own
/// region-scoping already key off of. Keep this alias table in sync with
/// node-api/utils/region.js if that one changes.
String normalizeRegionId(String? value) {
  if (value == null || value.trim().isEmpty) return '';

  var normalized = value
      .toLowerCase()
      .replaceAll('centre', 'center')
      .replaceAll('region', '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  const aliases = <String, String>{
    'north west': 'northwest',
    'northwest': 'northwest',
    'south west': 'southwest',
    'southwest': 'southwest',
    'far north': 'far-north',
    'center': 'centre',
    'center province': 'centre',
    'centre province': 'centre',
    'yaounde': 'centre',
    'yaound': 'centre',
    'douala': 'littoral',
    'bamenda': 'northwest',
    'buea': 'southwest',
    'limbe': 'southwest',
  };

  final resolved = aliases[normalized] ?? normalized;
  return resolved.replaceAll(RegExp(r'\s+'), '-');
}
