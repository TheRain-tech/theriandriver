import '../mock/mock_driver_profile.dart';
import '../models/driver_profile.dart';

class DriverProfileRepository {
  DriverProfile _profile = mockDriverProfile;

  Future<DriverProfile> getProfile() async => _profile;

  Future<DriverProfile> updateProfile(DriverProfile profile) async {
    _profile = profile;
    return _profile;
  }
}
