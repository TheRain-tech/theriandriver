typedef FuelSnapshot = ({
  double level,
  double efficiencyKmPerLitre,
  DateTime updatedAt,
});

class FuelTrackingRepository {
  Future<FuelSnapshot> getFuelSnapshot() async => (
    level: .78,
    efficiencyKmPerLitre: 12.5,
    updatedAt: DateTime(2026, 6, 6, 8, 30),
  );
}
