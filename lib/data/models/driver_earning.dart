class DriverEarning {
  const DriverEarning({
    required this.id,
    required this.driverId,
    required this.period,
    required this.total,
    required this.baseFares,
    required this.bonuses,
    required this.tips,
    required this.deductions,
    required this.tripCount,
    required this.onlineMinutes,
    required this.createdAt,
  });

  final String id;
  final String driverId;
  final String period;
  final double total;
  final double baseFares;
  final double bonuses;
  final double tips;
  final double deductions;
  final int tripCount;
  final int onlineMinutes;
  final DateTime createdAt;

  factory DriverEarning.fromJson(Map<String, dynamic> json) => DriverEarning(
    id: json['id'] as String,
    driverId: json['driverId'] as String,
    period: json['period'] as String,
    total: (json['total'] as num).toDouble(),
    baseFares: (json['baseFares'] as num).toDouble(),
    bonuses: (json['bonuses'] as num).toDouble(),
    tips: (json['tips'] as num).toDouble(),
    deductions: (json['deductions'] as num).toDouble(),
    tripCount: json['tripCount'] as int,
    onlineMinutes: json['onlineMinutes'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'period': period,
    'total': total,
    'baseFares': baseFares,
    'bonuses': bonuses,
    'tips': tips,
    'deductions': deductions,
    'tripCount': tripCount,
    'onlineMinutes': onlineMinutes,
    'createdAt': createdAt.toIso8601String(),
  };
}
