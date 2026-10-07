import 'package:flutter/animation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Tweens a map marker smoothly from wherever it currently is to each new GPS/snapped fix, instead
/// of jumping instantly on every update - the "avoid visual teleportation" requirement for the
/// driver's live position marker. Never invents movement: it only ever interpolates toward a real
/// position the caller gives it, and holds still once it arrives.
class DriverPositionAnimator {
  DriverPositionAnimator({
    required TickerProvider vsync,
    required VoidCallback onTick,
    Duration duration = const Duration(milliseconds: 900),
  }) : _onTick = onTick,
       controller = AnimationController(vsync: vsync, duration: duration) {
    controller.addListener(_handleTick);
  }

  final AnimationController controller;
  final VoidCallback _onTick;
  LatLng? _from;
  LatLng? _to;

  /// The current, interpolated position - null until the first [animateTo] call.
  LatLng? value;

  void _handleTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = Curves.easeInOut.transform(controller.value);
    value = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    _onTick();
  }

  /// Starts (or retargets, mid-flight, from the current interpolated point - never from the stale
  /// original start) an animation toward [target]. A no-op if already animating toward it.
  void animateTo(LatLng target) {
    if (_to == target) return;
    final current = value ?? target;
    _from = current;
    _to = target;
    value = current;
    controller
      ..stop()
      ..reset()
      ..forward();
  }

  void dispose() => controller.dispose();
}
