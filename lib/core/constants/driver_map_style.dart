/// Keeps the native Google Maps surfaces visually aligned with the light,
/// low-contrast map treatment used across TheRain's rider and driver apps.
abstract final class DriverMapStyle {
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
