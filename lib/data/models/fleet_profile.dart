import 'package:cloud_firestore/cloud_firestore.dart';

class FleetProfile {
  const FleetProfile({
    required this.fleetId,
    required this.fleetName,
    required this.fleetOwnerId,
    required this.businessName,
    required this.businessPhone,
    required this.businessEmail,
    required this.city,
    required this.status,
    required this.commissionPolicy,
    required this.payoutPolicy,
    required this.driversCount,
    required this.vehiclesCount,
    this.createdAt,
    this.updatedAt,
  });

  final String fleetId;
  final String fleetName;
  final String fleetOwnerId;
  final String businessName;
  final String businessPhone;
  final String businessEmail;
  final String city;
  final String status;
  final String commissionPolicy;
  final String payoutPolicy;
  final int driversCount;
  final int vehiclesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FleetProfile.fromMap(Map<String, dynamic> map, String id) {
    return FleetProfile(
      fleetId: map['fleetId']?.toString() ?? id,
      fleetName: map['fleetName']?.toString() ?? '',
      fleetOwnerId: map['fleetOwnerId']?.toString() ?? '',
      businessName: map['businessName']?.toString() ?? '',
      businessPhone: map['businessPhone']?.toString() ?? '',
      businessEmail: map['businessEmail']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      commissionPolicy: map['commissionPolicy']?.toString() ?? 'fleet_pays',
      payoutPolicy: map['payoutPolicy']?.toString() ?? 'fleet',
      driversCount: (map['driversCount'] as num?)?.toInt() ?? 0,
      vehiclesCount: (map['vehiclesCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
