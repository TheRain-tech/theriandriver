import 'package:flutter/foundation.dart';

class RegistrationDraft {
  const RegistrationDraft({
    this.fullName = '',
    this.phoneNumber = '',
    this.email = '',
    this.vehicleType = 'classic',
    this.vehiclePlateNumber = '',
    this.vehicleColor = 'Black',
    this.nationalIdNumber = '',
    this.nationalIdPhotoPath,
    this.driverLicenceNumber = '',
    this.driverLicenceExpiryDate,
    this.driverLicencePhotoPath,
    this.selfiePhotoPath,
    this.selfieBytes,
  });

  final String fullName;
  final String phoneNumber;
  final String email;
  final String vehicleType;
  final String vehiclePlateNumber;
  final String vehicleColor;
  final String nationalIdNumber;
  final String? nationalIdPhotoPath;
  final String driverLicenceNumber;
  final DateTime? driverLicenceExpiryDate;
  final String? driverLicencePhotoPath;
  final String? selfiePhotoPath;
  final Uint8List? selfieBytes;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      vehicleType.trim().isNotEmpty &&
      vehiclePlateNumber.trim().isNotEmpty &&
      nationalIdNumber.trim().isNotEmpty &&
      nationalIdPhotoPath != null &&
      driverLicenceNumber.trim().isNotEmpty &&
      driverLicenceExpiryDate != null &&
      driverLicencePhotoPath != null &&
      selfiePhotoPath != null;

  RegistrationDraft copyWith({
    String? fullName,
    String? phoneNumber,
    String? email,
    String? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleColor,
    String? nationalIdNumber,
    String? nationalIdPhotoPath,
    String? driverLicenceNumber,
    DateTime? driverLicenceExpiryDate,
    String? driverLicencePhotoPath,
    String? selfiePhotoPath,
    Uint8List? selfieBytes,
    bool clearSelfieBytes = false,
  }) {
    return RegistrationDraft(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      nationalIdPhotoPath: nationalIdPhotoPath ?? this.nationalIdPhotoPath,
      driverLicenceNumber: driverLicenceNumber ?? this.driverLicenceNumber,
      driverLicenceExpiryDate:
          driverLicenceExpiryDate ?? this.driverLicenceExpiryDate,
      driverLicencePhotoPath:
          driverLicencePhotoPath ?? this.driverLicencePhotoPath,
      selfiePhotoPath: selfiePhotoPath ?? this.selfiePhotoPath,
      selfieBytes: clearSelfieBytes ? null : selfieBytes ?? this.selfieBytes,
    );
  }
}

class RegistrationDraftService {
  RegistrationDraftService._();

  static final instance = RegistrationDraftService._();

  final ValueNotifier<RegistrationDraft> draft = ValueNotifier(
    const RegistrationDraft(),
  );

  RegistrationDraft get value => draft.value;

  void updateProfile({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String vehicleColor,
  }) {
    draft.value = draft.value.copyWith(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      email: email.trim().toLowerCase(),
      vehicleType: vehicleType.trim().toLowerCase(),
      vehiclePlateNumber: vehiclePlateNumber.trim().toUpperCase(),
      vehicleColor: vehicleColor.trim(),
    );
  }

  void updateNationalId({required String number, required String photoPath}) {
    draft.value = draft.value.copyWith(
      nationalIdNumber: number.trim(),
      nationalIdPhotoPath: photoPath,
    );
  }

  void updateLicence({
    required String number,
    required DateTime expiryDate,
    required String photoPath,
  }) {
    draft.value = draft.value.copyWith(
      driverLicenceNumber: number.trim(),
      driverLicenceExpiryDate: expiryDate,
      driverLicencePhotoPath: photoPath,
    );
  }

  void setSelfieBytes(Uint8List bytes) {
    draft.value = draft.value.copyWith(selfieBytes: bytes);
  }

  void setSelfiePath(String path) {
    draft.value = draft.value.copyWith(
      selfiePhotoPath: path,
      clearSelfieBytes: true,
    );
  }

  void clear() => draft.value = const RegistrationDraft();
}
