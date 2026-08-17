import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/driver_profile_service.dart';
import '../../../data/models/app_enums.dart';

typedef ToggleCallback = Future<void> Function();

class SwipeToggleButton extends StatefulWidget {
  const SwipeToggleButton({
    super.key,
    required this.onToggle,
    this.enabled = true,
  });

  final ToggleCallback onToggle;
  final bool enabled;

  @override
  State<SwipeToggleButton> createState() => _SwipeToggleButtonState();
}

class _SwipeToggleButtonState extends State<SwipeToggleButton>
    with SingleTickerProviderStateMixin {
  static const _offlineColor = Color(0xFFD32F2F);
  static const _onlineColor = Color(0xFF2E7D32);
  static const double _height = 65;
  static const double _thumbSize = 52;
  static const double _horizontalPadding = 32;
  static const double _swipeThreshold = 0.7;

  late AnimationController _ctrl;
  late Animation<Color?> _colorAnim;

  double _pos = 0.0; // 0=offline (thumb left), 1=online (thumb right)
  double _dragStartPos = 0.0;
  bool _dragStartedOnline = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _colorAnim = ColorTween(begin: _offlineColor, end: _onlineColor)
        .animate(_ctrl);
    // initialize position from profile
    final profile = DriverProfileService.instance.profile.value;
    // set _pos to 1.0 if online, 0.0 if offline
    _pos = profile.onlineStatus == DriverOnlineStatus.offline ? 0.0 : 1.0;
    _ctrl.value = _pos;
    DriverProfileService.instance.profile.addListener(_profileListener);
  }

  void _profileListener() {
    final profile = DriverProfileService.instance.profile.value;
    final target = profile.onlineStatus == DriverOnlineStatus.offline ? 0.0 : 1.0;
    if ((target - _pos).abs() > 0.001) {
      _animateTo(target);
    }
  }

  @override
  void dispose() {
    DriverProfileService.instance.profile.removeListener(_profileListener);
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double t) {
    _ctrl.animateTo(t, curve: Curves.elasticOut).then((_) {
      setState(() => _pos = _ctrl.value);
    });
  }

  void _onDragStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _dragStartPos = _pos * trackWidth;
    _dragStartedOnline = _pos >= 0.5;
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _dragStartPos += details.delta.dx;
    final v = (_dragStartPos / trackWidth).clamp(0.0, 1.0);
    _ctrl.value = v;
    setState(() => _pos = v);
  }

  Future<void> _onDragEnd(DragEndDetails details, double trackWidth) async {
    if (!widget.enabled) {
      _animateTo(_pos < 0.5 ? 0.0 : 1.0);
      return;
    }
    // Threshold is measured from the state the drag started in: 70% of the
    // track must be crossed to flip state, otherwise it springs back.
    final crossedThreshold = _dragStartedOnline
        ? _pos <= (1 - _swipeThreshold)
        : _pos >= _swipeThreshold;
    final triggeredOnline = crossedThreshold
        ? !_dragStartedOnline
        : _dragStartedOnline;
    _animateTo(triggeredOnline ? 1.0 : 0.0);
    if (crossedThreshold) {
      HapticFeedback.mediumImpact();
      try {
        await widget.onToggle();
      } catch (_) {}
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(triggeredOnline
            ? 'You are now online and visible to riders'
            : 'You are now offline'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final trackWidth = math.max(1.0, width - (_horizontalPadding * 2) - _thumbSize);
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final bgColor = _colorAnim.value ?? _offlineColor;
          final isOnline = _ctrl.value >= 0.5;
          return Container(
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background pill
                Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                // Center text
                Center(
                  child: Text(
                    isOnline ? '← Swipe to Go Offline' : 'Swipe to Go Online →',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Draggable thumb
                Positioned(
                  left: _ctrl.value * trackWidth,
                  child: GestureDetector(
                    onHorizontalDragStart: (d) => _onDragStart(d, trackWidth),
                    onHorizontalDragUpdate: (d) => _onDragUpdate(d, trackWidth),
                    onHorizontalDragEnd: (d) => _onDragEnd(d, trackWidth),
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          color: isOnline ? _onlineColor : _offlineColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
