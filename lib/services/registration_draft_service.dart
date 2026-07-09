import 'package:flutter/foundation.dart';

class RegistrationDraft {
  const RegistrationDraft({
    this.fullName = '',
    this.phoneNumber = '',
    this.email = '',
    this.password = '',
    this.vehicleType = 'classic',
    this.vehicleModel = '',
    this.vehiclePlateNumber = '',
    this.vehicleColor = 'Black',
    this.numberOfSeats = 4,
    this.cityRegion = '',
    this.nationalIdNumber = '',
    this.nationalIdPhotoPath,
    this.nationalIdPhotoBytes,
    this.driverLicenceNumber = '',
    this.driverLicenceExpiryDate,
    this.driverLicencePhotoPath,
    this.driverLicencePhotoBytes,
    this.selfiePhotoPath,
    this.selfieBytes,
    this.payoutProvider = 'mtn_momo',
    this.payoutAccountName = '',
    this.payoutAccountNumber = '',
    this.acceptedTerms = false,
  });

  final String fullName;
  final String phoneNumber;
  final String email;
  final String password;
  final String vehicleType;
  final String vehicleModel;
  final String vehiclePlateNumber;
  final String vehicleColor;
  final int numberOfSeats;
  final String cityRegion;
  final String nationalIdNumber;
  final String? nationalIdPhotoPath;
  final Uint8List? nationalIdPhotoBytes;
  final String driverLicenceNumber;
  final DateTime? driverLicenceExpiryDate;
  final String? driverLicencePhotoPath;
  final Uint8List? driverLicencePhotoBytes;
  final String? selfiePhotoPath;
  final Uint8List? selfieBytes;
  final String payoutProvider;
  final String payoutAccountName;
  final String payoutAccountNumber;
  final bool acceptedTerms;

  bool get hasSignupCredentials =>
      fullName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      password.trim().length >= 6 &&
      acceptedTerms;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      vehicleType.trim().isNotEmpty &&
      vehicleModel.trim().isNotEmpty &&
      vehiclePlateNumber.trim().isNotEmpty &&
      numberOfSeats > 0 &&
      cityRegion.trim().isNotEmpty &&
      nationalIdNumber.trim().isNotEmpty &&
      (nationalIdPhotoPath != null || nationalIdPhotoBytes != null) &&
      driverLicenceNumber.trim().isNotEmpty &&
      driverLicenceExpiryDate != null &&
      (driverLicencePhotoPath != null || driverLicencePhotoBytes != null) &&
      (selfiePhotoPath != null || selfieBytes != null) &&
      acceptedTerms;

  RegistrationDraft copyWith({
    String? fullName,
    String? phoneNumber,
    String? email,
    String? password,
    String? vehicleType,
    String? vehicleModel,
    String? vehiclePlateNumber,
    String? vehicleColor,
    int? numberOfSeats,
    String? cityRegion,
    String? nationalIdNumber,
    String? nationalIdPhotoPath,
    Uint8List? nationalIdPhotoBytes,
    String? driverLicenceNumber,
    DateTime? driverLicenceExpiryDate,
    String? driverLicencePhotoPath,
    Uint8List? driverLicencePhotoBytes,
    String? selfiePhotoPath,
    Uint8List? selfieBytes,
    String? payoutProvider,
    String? payoutAccountName,
    String? payoutAccountNumber,
    bool? acceptedTerms,
    bool clearNationalIdBytes = false,
    bool clearDriverLicenceBytes = false,
    bool clearSelfieBytes = false,
  }) {
    return RegistrationDraft(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      password: password ?? this.password,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      numberOfSeats: numberOfSeats ?? this.numberOfSeats,
      cityRegion: cityRegion ?? this.cityRegion,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      nationalIdPhotoPath: nationalIdPhotoPath ?? this.nationalIdPhotoPath,
      nationalIdPhotoBytes: clearNationalIdBytes
          ? null
          : nationalIdPhotoBytes ?? this.nationalIdPhotoBytes,
      driverLicenceNumber: driverLicenceNumber ?? this.driverLicenceNumber,
      driverLicenceExpiryDate:
          driverLicenceExpiryDate ?? this.driverLicenceExpiryDate,
      driverLicencePhotoPath:
          driverLicencePhotoPath ?? this.driverLicencePhotoPath,
      driverLicencePhotoBytes: clearDriverLicenceBytes
          ? null
          : driverLicencePhotoBytes ?? this.driverLicencePhotoBytes,
      selfiePhotoPath: selfiePhotoPath ?? this.selfiePhotoPath,
      selfieBytes: clearSelfieBytes ? null : selfieBytes ?? this.selfieBytes,
      payoutProvider: payoutProvider ?? this.payoutProvider,
      payoutAccountName: payoutAccountName ?? this.payoutAccountName,
      payoutAccountNumber: payoutAccountNumber ?? this.payoutAccountNumber,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
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
    String? password,
    required String vehicleType,
    required String vehicleModel,
    required String vehiclePlateNumber,
    required String vehicleColor,
    required int numberOfSeats,
    required String cityRegion,
    required String payoutProvider,
    required String payoutAccountName,
    required String payoutAccountNumber,
    bool? acceptedTerms,
  }) {
    draft.value = draft.value.copyWith(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      email: email.trim().toLowerCase(),
      password: password?.trim(),
      vehicleType: vehicleType.trim().toLowerCase(),
      vehicleModel: vehicleModel.trim(),
      vehiclePlateNumber: vehiclePlateNumber.trim().toUpperCase(),
      vehicleColor: vehicleColor.trim(),
      numberOfSeats: numberOfSeats,
      cityRegion: cityRegion.trim(),
      payoutProvider: payoutProvider.trim().toLowerCase(),
      payoutAccountName: payoutAccountName.trim(),
      payoutAccountNumber: payoutAccountNumber.trim(),
      acceptedTerms: acceptedTerms,
    );
  }

  void updateSignupCredentials({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) {
    draft.value = draft.value.copyWith(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      email: email.trim().toLowerCase(),
      password: password.trim(),
      acceptedTerms: acceptedTerms,
    );
  }

  void updateNationalId({
    required String number,
    required String photoPath,
    Uint8List? photoBytes,
  }) {
    draft.value = draft.value.copyWith(
      nationalIdNumber: number.trim(),
      nationalIdPhotoPath: photoPath,
      nationalIdPhotoBytes: photoBytes,
    );
  }

  void updateLicence({
    required String number,
    required DateTime expiryDate,
    required String photoPath,
    Uint8List? photoBytes,
  }) {
    draft.value = draft.value.copyWith(
      driverLicenceNumber: number.trim(),
      driverLicenceExpiryDate: expiryDate,
      driverLicencePhotoPath: photoPath,
      driverLicencePhotoBytes: photoBytes,
    );
  }

  void setSelfieBytes(Uint8List bytes) {
    draft.value = draft.value.copyWith(selfieBytes: bytes);
  }

  void setSelfiePath(String path, {bool clearBytes = false}) {
    draft.value = draft.value.copyWith(
      selfiePhotoPath: path,
      clearSelfieBytes: clearBytes,
    );
  }

  void clear() => draft.value = const RegistrationDraft();
}
