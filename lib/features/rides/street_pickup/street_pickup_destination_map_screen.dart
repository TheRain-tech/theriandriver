import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/driver_map_style.dart';
import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/ride_request.dart';
import '../../../data/repositories/street_pickup_repository.dart';
import '../../../theme/app_colors.dart';

/// "Choose on map" for the Street Pickup destination - the driver-app counterpart of the rider
/// app's ChooseDestinationOnMapScreen (therian map_pin_selection_screen.dart): drag the map
/// under a fixed centre pin, the address under it is looked up once the map settles, then
/// Confirm. Pops with the chosen [RideLocation], or null for "Search instead".
class StreetPickupDestinationMapScreen extends StatefulWidget {
  const StreetPickupDestinationMapScreen({
    super.key,
    required this.copy,
    this.initialLat,
    this.initialLng,
  });

  final DriverCopy copy;
  final double? initialLat;
  final double? initialLng;

  @override
  State<StreetPickupDestinationMapScreen> createState() =>
      _StreetPickupDestinationMapScreenState();
}

class _StreetPickupDestinationMapScreenState
    extends State<StreetPickupDestinationMapScreen> {
  // Douala - only used when the driver's own position isn't known yet.
  static const _fallbackTarget = LatLng(4.0511, 9.7679);

  final _repository = StreetPickupRepository();
  late LatLng _target = widget.initialLat != null && widget.initialLng != null
      ? LatLng(widget.initialLat!, widget.initialLng!)
      : _fallbackTarget;
  String? _address;
  bool _isMoving = false;
  bool _isResolving = true;
  int _lookupGeneration = 0;

  DriverCopy get l => widget.copy;

  @override
  void initState() {
    super.initState();
    _lookupAddress();
  }

  void _onCameraMove(CameraPosition position) {
    _target = position.target;
    if (!_isMoving) setState(() => _isMoving = true);
  }

  void _onCameraIdle() {
    setState(() => _isMoving = false);
    _lookupAddress();
  }

  Future<void> _lookupAddress() async {
    final generation = ++_lookupGeneration;
    final target = _target;
    setState(() => _isResolving = true);
    final address = await _repository.addressAt(
      target.latitude,
      target.longitude,
    );
    if (!mounted || generation != _lookupGeneration) return;
    setState(() {
      _address = address;
      _isResolving = false;
    });
  }

  void _confirm() {
    final address = _address;
    if (address == null || address.trim().isEmpty) return;
    Navigator.pop(
      context,
      RideLocation(
        lat: _target.latitude,
        lng: _target.longitude,
        address: address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        !_isMoving &&
        !_isResolving &&
        _address != null &&
        _address!.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _target, zoom: 16),
            style: AppColors.isDark(context)
                ? DriverMapStyle.dark
                : DriverMapStyle.light,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 45),
              child: _DestinationPin(isMoving: _isMoving),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surfaceFor(context),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: AppColors.surfaceFor(context),
                      borderRadius: BorderRadius.circular(14),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l.t(
                                    'Search destination',
                                    'Rechercher une destination',
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textSecondaryFor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFor(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.t('Destination', 'Destination'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isMoving || _isResolving
                                ? l.t(
                                    'Finding address...',
                                    "Recherche de l'adresse...",
                                  )
                                : _address ??
                                      l.t(
                                        'Address not found here. Move the map a little.',
                                        'Adresse introuvable ici. Déplacez un peu la carte.',
                                      ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryFor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.t(
                        'Move the map to place the destination pin.',
                        'Déplacez la carte pour placer le repère de destination.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: l.t(
                        'Confirm destination',
                        'Confirmer la destination',
                      ),
                      isLoading: _isResolving && !_isMoving,
                      onPressed: canConfirm ? _confirm : null,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.t('Search instead', 'Rechercher plutôt')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same centre pin as the rider app's MapCenterPin (destination variant).
class _DestinationPin extends StatelessWidget {
  const _DestinationPin({required this.isMoving});

  final bool isMoving;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.navy;
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 160),
        offset: isMoving ? const Offset(0, -0.14) : Offset.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: color,
                size: 27,
              ),
            ),
            Container(width: 3, height: 17, color: color),
            Container(
              width: 12,
              height: 5,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
