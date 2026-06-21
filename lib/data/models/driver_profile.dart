import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_enums.dart';

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.rating,
    required this.totalTrips,
    required this.onlineStatus,
    required this.verificationStatus,
    this.avatarUrl,
    this.vehicleId,
    this.memberSince,
    this.accountStatus = 'pending',
    this.canReceiveRides = false,
    this.currentRideId,
    this.currentRideStatus,
    this.vehicleType = '',
    this.vehiclePlateNumber = '',
    this.vehicleColor = '',
    this.totalEarnings = 0,
    this.walletBalance = 0,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final double rating;
  final int totalTrips;
  final DriverOnlineStatus onlineStatus;
  final DriverVerificationStatus verificationStatus;
  final String? avatarUrl;
  final String? vehicleId;
  final DateTime? memberSince;
  final String accountStatus;
  final bool canReceiveRides;
  final String? currentRideId;
  final String? currentRideStatus;
  final String vehicleType;
  final String vehiclePlateNumber;
  final String vehicleColor;
  final double totalEarnings;
  final double walletBalance;

  DriverProfile copyWith({
    String? fullName,
    String? phone,
    String? email,
    DriverOnlineStatus? onlineStatus,
    DriverVerificationStatus? verificationStatus,
    String? accountStatus,
    bool? canReceiveRides,
    String? currentRideId,
    String? currentRideStatus,
    String? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleColor,
    double? totalEarnings,
    double? walletBalance,
  }) {
    return DriverProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rating: rating,
      totalTrips: totalTrips,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      avatarUrl: avatarUrl,
      vehicleId: vehicleId,
      memberSince: memberSince,
      accountStatus: accountStatus ?? this.accountStatus,
      canReceiveRides: canReceiveRides ?? this.canReceiveRides,
      currentRideId: currentRideId ?? this.currentRideId,
      currentRideStatus: currentRideStatus ?? this.currentRideStatus,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }

  factory DriverProfile.fromJson(Map<String, dynamic> json) =>
      DriverProfile.fromMap(json, json['id']?.toString() ?? '');

  factory DriverProfile.fromMap(Map<String, dynamic> map, String id) {
    final status = map['status']?.toString();
    final isOnline = map['isOnline'] == true || status == 'online';
    final isBusy = status == 'busy';

    return DriverProfile(
      id: map['uid']?.toString() ?? map['driverId']?.toString() ?? id,
      fullName: map['fullName']?.toString() ?? '',
      phone: map['phoneNumber']?.toString() ?? map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalTrips: (map['totalTrips'] as num?)?.toInt() ?? 0,
      onlineStatus: isBusy
          ? DriverOnlineStatus.busy
          : isOnline
          ? DriverOnlineStatus.online
          : DriverOnlineStatus.offline,
      verificationStatus: enumByName(
        DriverVerificationStatus.values,
        map['verificationStatus'],
        DriverVerificationStatus.notStarted,
      ),
      avatarUrl:
          map['profileImageUrl']?.toString() ??
          map['profilePhotoPath']?.toString() ??
          map['avatarUrl']?.toString(),
      vehicleId:
          map['defaultVehicleId']?.toString() ?? map['vehicleId']?.toString(),
      memberSince: _date(map['createdAt']) ?? _date(map['memberSince']),
      accountStatus: map['accountStatus']?.toString() ?? 'pending',
      canReceiveRides: map['canReceiveRides'] == true,
      currentRideId: _optional(map['currentRideId']),
      currentRideStatus: _optional(map['currentRideStatus']),
      vehicleType: map['vehicleType']?.toString() ?? '',
      vehiclePlateNumber: map['vehiclePlateNumber']?.toString() ?? '',
      vehicleColor: map['vehicleColor']?.toString() ?? '',
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'rating': rating,
    'totalTrips': totalTrips,
    'onlineStatus': onlineStatus.name,
    'verificationStatus': verificationStatus.name,
    'avatarUrl': avatarUrl,
    'vehicleId': vehicleId,
    'memberSince': memberSince?.toIso8601String(),
    'accountStatus': accountStatus,
    'canReceiveRides': canReceiveRides,
    'currentRideId': currentRideId,
    'currentRideStatus': currentRideStatus,
    'vehicleType': vehicleType,
    'vehiclePlateNumber': vehiclePlateNumber,
    'vehicleColor': vehicleColor,
    'totalEarnings': totalEarnings,
    'walletBalance': walletBalance,
  };

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
