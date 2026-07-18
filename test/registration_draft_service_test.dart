import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/services/registration_draft_service.dart';

void main() {
  setUp(() => RegistrationDraftService.instance.clear());
  tearDown(() => RegistrationDraftService.instance.clear());

  test('updateRegion/updateAffiliation/updateServiceTypes/updateVehicleCategory set the draft', () {
    final service = RegistrationDraftService.instance;
    service.updateRegion('littoral');
    service.updateAffiliation('fleet');
    service.updateServiceTypes(['ride_hailing', 'delivery']);
    service.updateVehicleCategory('van');

    expect(service.value.regionId, 'littoral');
    expect(service.value.affiliationType, 'fleet');
    expect(service.value.serviceTypes, ['ride_hailing', 'delivery']);
    expect(service.value.vehicleCategory, 'van');
  });

  test('a fresh draft has no taxonomy set and is not complete', () {
    final draft = RegistrationDraftService.instance.value;
    expect(draft.regionId, isNull);
    expect(draft.affiliationType, isNull);
    expect(draft.serviceTypes, isEmpty);
    expect(draft.vehicleCategory, isNull);
    expect(draft.isComplete, isFalse);
  });

  test('isComplete requires every taxonomy field to be set, not only the pre-existing ones', () {
    final service = RegistrationDraftService.instance;
    service.updateProfile(
      fullName: 'Test Driver',
      phoneNumber: '671234567',
      email: 'driver@example.com',
      vehicleType: 'classic',
      vehicleModel: 'Corolla',
      vehiclePlateNumber: 'LT123AB',
      vehicleColor: 'Black',
      numberOfSeats: 4,
      cityRegion: 'Douala',
      payoutProvider: 'mtn_momo',
      payoutAccountName: 'Test Driver',
      payoutAccountNumber: '671234567',
      acceptedTerms: true,
    );
    // Taxonomy not yet set - still incomplete even though every legacy field is filled.
    expect(service.value.isComplete, isFalse);

    service.updateRegion('littoral');
    service.updateAffiliation('independent');
    service.updateServiceTypes(['ride_hailing']);
    service.updateVehicleCategory('car');
    // Still missing the document/selfie/national-ID fields isComplete also requires.
    expect(service.value.isComplete, isFalse);
  });

  test('clear() resets taxonomy fields along with everything else', () {
    final service = RegistrationDraftService.instance;
    service.updateRegion('littoral');
    service.clear();
    expect(service.value.regionId, isNull);
  });
}
