import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/services/location_service.dart';

void main() {
  test('only the terminal trip can release the tracked ride marker', () {
    expect(
      shouldReleaseTrackedRide(currentRideId: 'ride-a', endingRideId: 'ride-a'),
      isTrue,
    );
    expect(
      shouldReleaseTrackedRide(currentRideId: 'ride-b', endingRideId: 'ride-a'),
      isFalse,
    );
  });
}
