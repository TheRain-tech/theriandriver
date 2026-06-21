class DriverSubscription {
  const DriverSubscription({
    required this.id,
    required this.driverId,
    required this.planName,
    required this.price,
    required this.isActive,
    required this.startedAt,
    required this.validUntil,
    required this.benefits,
  });

  final String id;
  final String driverId;
  final String planName;
  final double price;
  final bool isActive;
  final DateTime startedAt;
  final DateTime validUntil;
  final List<String> benefits;

  factory DriverSubscription.fromJson(Map<String, dynamic> json) =>
      DriverSubscription(
        id: json['id'] as String,
        driverId: json['driverId'] as String,
        planName: json['planName'] as String,
        price: (json['price'] as num).toDouble(),
        isActive: json['isActive'] as bool,
        startedAt: DateTime.parse(json['startedAt'] as String),
        validUntil: DateTime.parse(json['validUntil'] as String),
        benefits: List<String>.from(json['benefits'] as List),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'planName': planName,
    'price': price,
    'isActive': isActive,
    'startedAt': startedAt.toIso8601String(),
    'validUntil': validUntil.toIso8601String(),
    'benefits': benefits,
  };
}
