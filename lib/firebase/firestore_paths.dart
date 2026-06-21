import 'firestore_collections.dart';

abstract final class FirestorePaths {
  static String user(String uid) => '${FirestoreCollections.users}/$uid';
  static String driver(String uid) => '${FirestoreCollections.drivers}/$uid';
  static String driverVerification(String uid) =>
      '${FirestoreCollections.driverVerifications}/$uid';
  static String driverLiveLocation(String uid) =>
      '${FirestoreCollections.driverLiveLocations}/$uid';
  static String riderLiveLocation(String riderId) =>
      '${FirestoreCollections.riderLiveLocations}/$riderId';
  static String rideRequest(String requestId) =>
      '${FirestoreCollections.rideRequests}/$requestId';
  static String ride(String rideId) => '${FirestoreCollections.rides}/$rideId';
  static String driverWallet(String uid) =>
      '${FirestoreCollections.driverWallets}/$uid';
}
