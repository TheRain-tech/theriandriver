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
    this.authUid,
    this.driverType = 'individual',
    this.fleetId,
    this.fleetOwnerId,
    this.fleetName,
    this.createdBy = 'self',
    this.credentialIssuedBy = 'self',
    this.mustChangePassword = false,
    this.firstLoginCompleted = true,
    this.accountStatus = 'pending',
    this.canGoOnline = false,
    this.canReceiveRides = false,
    this.commissionWalletStatus = 'empty',
    this.commissionWalletId,
    this.commissionWalletOwnerType = 'driver',
    this.payoutOwner = 'driver',
    this.payoutAccountId,
    this.currentRideId,
    this.currentRideStatus,
    this.vehicleType = '',
    this.vehicleModel = '',
    this.vehiclePlateNumber = '',
    this.vehicleColor = '',
    this.numberOfSeats = 0,
    this.cityRegion = '',
    this.vehicleStatus = 'pending',
    this.documentsValid = false,
    this.lockedFields = const <String>[],
    this.totalEarnings = 0,
    this.walletBalance = 0,
    this.phoneVerified = false,
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
  final String? authUid;
  final String driverType;
  final String? fleetId;
  final String? fleetOwnerId;
  final String? fleetName;
  final String createdBy;
  final String credentialIssuedBy;
  final bool mustChangePassword;
  final bool firstLoginCompleted;
  final String accountStatus;
  final bool canGoOnline;
  final bool canReceiveRides;
  final String commissionWalletStatus;
  final String? commissionWalletId;
  final String commissionWalletOwnerType;
  final String payoutOwner;
  final String? payoutAccountId;
  final String? currentRideId;
  final String? currentRideStatus;
  final String vehicleType;
  final String vehicleModel;
  final String vehiclePlateNumber;
  final String vehicleColor;
  final int numberOfSeats;
  final String cityRegion;
  final String vehicleStatus;
  final bool documentsValid;
  final List<String> lockedFields;
  final double totalEarnings;
  final double walletBalance;
  final bool phoneVerified;

  DriverProfile copyWith({
    String? fullName,
    String? phone,
    String? email,
    DriverOnlineStatus? onlineStatus,
    DriverVerificationStatus? verificationStatus,
    String? accountStatus,
    bool? canGoOnline,
    bool? canReceiveRides,
    String? currentRideId,
    String? currentRideStatus,
    String? vehicleType,
    String? vehicleModel,
    String? vehiclePlateNumber,
    String? vehicleColor,
    int? numberOfSeats,
    String? cityRegion,
    double? totalEarnings,
    double? walletBalance,
    bool? phoneVerified,
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
      authUid: authUid,
      driverType: driverType,
      fleetId: fleetId,
      fleetOwnerId: fleetOwnerId,
      fleetName: fleetName,
      createdBy: createdBy,
      credentialIssuedBy: credentialIssuedBy,
      mustChangePassword: mustChangePassword,
      firstLoginCompleted: firstLoginCompleted,
      accountStatus: accountStatus ?? this.accountStatus,
      canGoOnline: canGoOnline ?? this.canGoOnline,
      canReceiveRides: canReceiveRides ?? this.canReceiveRides,
      commissionWalletStatus: commissionWalletStatus,
      commissionWalletId: commissionWalletId,
      commissionWalletOwnerType: commissionWalletOwnerType,
      payoutOwner: payoutOwner,
      payoutAccountId: payoutAccountId,
      currentRideId: currentRideId ?? this.currentRideId,
      currentRideStatus: currentRideStatus ?? this.currentRideStatus,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      numberOfSeats: numberOfSeats ?? this.numberOfSeats,
      cityRegion: cityRegion ?? this.cityRegion,
      vehicleStatus: vehicleStatus,
      documentsValid: documentsValid,
      lockedFields: lockedFields,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      walletBalance: walletBalance ?? this.walletBalance,
      phoneVerified: phoneVerified ?? this.phoneVerified,
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
      authUid: _optional(map['authUid']) ?? _optional(map['uid']),
      driverType: map['driverType']?.toString() ?? 'individual',
      fleetId: _optional(map['fleetId']),
      fleetOwnerId: _optional(map['fleetOwnerId']),
      fleetName:
          _optional(map['fleetName']) ??
          _optional((map['fleetSummary'] as Map?)?['fleetName']),
      createdBy: map['createdBy']?.toString() ?? 'self',
      credentialIssuedBy: map['credentialIssuedBy']?.toString() ?? 'self',
      mustChangePassword: map['mustChangePassword'] == true,
      firstLoginCompleted: map['firstLoginCompleted'] != false,
      accountStatus: map['accountStatus']?.toString() ?? 'pending',
      canGoOnline: map['canGoOnline'] == true,
      canReceiveRides: map['canReceiveRides'] == true,
      commissionWalletStatus:
          map['commissionWalletStatus']?.toString() ?? 'empty',
      commissionWalletId: _optional(map['commissionWalletId']),
      commissionWalletOwnerType:
          map['commissionWalletOwnerType']?.toString() ?? 'driver',
      payoutOwner: map['payoutOwner']?.toString() ?? 'driver',
      payoutAccountId: _optional(map['payoutAccountId']),
      currentRideId: _optional(map['currentRideId']),
      currentRideStatus: _optional(map['currentRideStatus']),
      vehicleType: map['vehicleType']?.toString() ?? '',
      vehicleModel:
          map['vehicleModel']?.toString() ??
          _optional((map['vehicleSummary'] as Map?)?['model']) ??
          '',
      vehiclePlateNumber: map['vehiclePlateNumber']?.toString() ?? '',
      vehicleColor: map['vehicleColor']?.toString() ?? '',
      numberOfSeats:
          (map['numberOfSeats'] as num?)?.toInt() ??
          (map['seats'] as num?)?.toInt() ??
          0,
      cityRegion:
          map['cityRegion']?.toString() ?? map['city']?.toString() ?? '',
      vehicleStatus: map['vehicleStatus']?.toString() ?? 'pending',
      documentsValid: map['documentsValid'] == true,
      lockedFields: ((map['lockedFields'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
      phoneVerified: map['phoneVerified'] == true,
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
    'authUid': authUid,
    'driverType': driverType,
    'fleetId': fleetId,
    'fleetOwnerId': fleetOwnerId,
    'fleetName': fleetName,
    'createdBy': createdBy,
    'credentialIssuedBy': credentialIssuedBy,
    'mustChangePassword': mustChangePassword,
    'firstLoginCompleted': firstLoginCompleted,
    'accountStatus': accountStatus,
    'canGoOnline': canGoOnline,
    'canReceiveRides': canReceiveRides,
    'commissionWalletStatus': commissionWalletStatus,
    'commissionWalletId': commissionWalletId,
    'commissionWalletOwnerType': commissionWalletOwnerType,
    'payoutOwner': payoutOwner,
    'payoutAccountId': payoutAccountId,
    'currentRideId': currentRideId,
    'currentRideStatus': currentRideStatus,
    'vehicleType': vehicleType,
    'vehicleModel': vehicleModel,
    'vehiclePlateNumber': vehiclePlateNumber,
    'vehicleColor': vehicleColor,
    'numberOfSeats': numberOfSeats,
    'cityRegion': cityRegion,
    'vehicleStatus': vehicleStatus,
    'documentsValid': documentsValid,
    'lockedFields': lockedFields,
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
