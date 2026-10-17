/// One travelling passenger on a "Someone else"/"Group Ride" booking, as the
/// Driver app needs it - just enough to show who's riding and let the
/// driver call them. The Rider app's own GroupRidePassenger carries more
/// (pickup/dropoff overrides, notes, ordering) that the driver doesn't need.
class DriverTripPassenger {
  const DriverTripPassenger({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;

  factory DriverTripPassenger.fromMap(Map<String, dynamic> map) =>
      DriverTripPassenger(
        name: map['name']?.toString() ?? '',
        phoneNumber: map['phoneNumber']?.toString() ?? '',
      );

  static List<DriverTripPassenger> listFromDynamic(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => DriverTripPassenger.fromMap(entry.cast<String, dynamic>()))
        .toList();
  }
}
