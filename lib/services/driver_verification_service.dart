import 'package:flutter/foundation.dart';

import '../data/mock/mock_driver_verification.dart';
import '../data/models/app_enums.dart';
import '../data/models/driver_verification.dart';

class DriverVerificationService {
  DriverVerificationService._();

  static final instance = DriverVerificationService._();

  final ValueNotifier<DriverVerification> verification = ValueNotifier(
    mockDriverVerification,
  );

  DriverVerificationStatus get status => verification.value.status;

  void start() => _setStatus(DriverVerificationStatus.inProgress);
  void submit() => _setStatus(DriverVerificationStatus.pending);
  void approve() => _setStatus(DriverVerificationStatus.approved);
  void reject() => _setStatus(DriverVerificationStatus.rejected);
  void requireResubmission() =>
      _setStatus(DriverVerificationStatus.resubmissionRequired);
  void reset() => _setStatus(DriverVerificationStatus.notStarted);
  void syncStatus(DriverVerificationStatus status) => _setStatus(status);

  void _setStatus(DriverVerificationStatus status) {
    verification.value = verification.value.copyWith(status: status);
  }
}
