class DriverPromotion {
  const DriverPromotion({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  final String id;
  final String title;
  final String description;
  final double reward;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  factory DriverPromotion.fromJson(Map<String, dynamic> json) =>
      DriverPromotion(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        reward: (json['reward'] as num).toDouble(),
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        isActive: json['isActive'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'reward': reward,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'isActive': isActive,
  };
}
