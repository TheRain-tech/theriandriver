import 'package:cloud_functions/cloud_functions.dart';

import '../config/firebase_config.dart';

class PaymentService {
  PaymentService({FirebaseFunctions? functions})
    : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  Future<void> createRidePaymentSession({
    required String rideId,
    required String paymentMethod,
  }) async {
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Payment backend is unavailable.');
    }
    await _functions.httpsCallable('createRidePaymentSession').call({
      'rideId': rideId,
      'paymentMethod': paymentMethod,
    });
  }
}
