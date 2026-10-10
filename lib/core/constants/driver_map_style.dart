/// Keeps the native Google Maps surfaces visually aligned with the light,
/// low-contrast map treatment used across TheRain's rider and driver apps.
abstract final class DriverMapStyle {
  // Same palette as therian/lib/config/map_styles.dart's darkMapStyle - every TheRain map (rider
  // and driver) uses the identical dark style JSON so the brand looks consistent across apps,
  // not just within one of them.
  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#07162B"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8A9CB6"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#07162B"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#163664"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#566D8E"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#0A1A33"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#0D223F"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#8A9CB6"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#0D223F"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#163664"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#0F2A52"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#163664"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#0AB4FF"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#0A1A33"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#8A9CB6"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#030A16"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#566D8E"}]}
]
''';

  static const light = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f8fc"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#5b6b85"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#edf3fa"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#7b8ca6"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e1eaf4"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#d7ecff"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#b5d9fa"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#edf3fa"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9eaff"}]}
]
''';
}
