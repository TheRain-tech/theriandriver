import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/repositories/ride_repository.dart';

void main() {
  test('an idle driver never queues - normal acceptance path', () {
    expect(
      shouldQueueAcceptance(
        driverIsBusy: false,
        acceptingNextRide: true,
        currentRideStatus: 'in_progress',
        queuedRideId: null,
      ),
      isFalse,
    );
  });

  test('a busy driver who never opted in cannot queue', () {
    expect(
      shouldQueueAcceptance(
        driverIsBusy: true,
        acceptingNextRide: false,
        currentRideStatus: 'in_progress',
        queuedRideId: null,
      ),
      isFalse,
    );
  });

  test('a busy, opted-in driver still heading to or waiting at pickup cannot queue', () {
    for (final status in ['driver_assigned', 'driver_arriving', 'driver_arrived']) {
      expect(
        shouldQueueAcceptance(
          driverIsBusy: true,
          acceptingNextRide: true,
          currentRideStatus: status,
          queuedRideId: null,
        ),
        isFalse,
        reason: 'expected false for currentRideStatus=$status',
      );
    }
  });

  test('a busy, opted-in, in_progress driver with nothing already queued can queue', () {
    expect(
      shouldQueueAcceptance(
        driverIsBusy: true,
        acceptingNextRide: true,
        currentRideStatus: 'in_progress',
        queuedRideId: null,
      ),
      isTrue,
    );
    expect(
      shouldQueueAcceptance(
        driverIsBusy: true,
        acceptingNextRide: true,
        currentRideStatus: 'in_progress',
        queuedRideId: '',
      ),
      isTrue,
    );
  });

  test('a busy, opted-in, in_progress driver who already has one queued cannot queue a second', () {
    expect(
      shouldQueueAcceptance(
        driverIsBusy: true,
        acceptingNextRide: true,
        currentRideStatus: 'in_progress',
        queuedRideId: 'ride-2',
      ),
      isFalse,
    );
  });
}
