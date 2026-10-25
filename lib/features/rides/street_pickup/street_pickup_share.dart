import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/street_pickup_repository.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';

/// Sharing a street pickup's trip details with the passenger, who has no TheRain account to see
/// them in. WhatsApp or SMS when the driver entered the passenger's number, otherwise the phone's
/// own share sheet so the driver can still hand the details over however suits them.
abstract final class StreetPickupShare {
  /// Digits only, with Cameroon's +237 added to a bare 9-digit local number - the form both
  /// wa.me links and sms: URIs need.
  static String internationalDigits(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 9) digits = '237$digits';
    return digits;
  }

  /// The pickup as a place name the passenger will recognise. The pickup address stored on the
  /// ride came from reverse geocoding the driver's GPS, which across much of Cameroon is a bare
  /// Plus Code ("X552+V8H"), so the coordinates are looked up again preferring a named place or
  /// neighbourhood. Falls back to the stored address with any Plus Code stripped.
  static Future<String> pickupName(DriverTrip trip) async {
    if (trip.pickupLat != 0 || trip.pickupLng != 0) {
      final readable = await StreetPickupRepository().readableAddressAt(
        trip.pickupLat,
        trip.pickupLng,
      );
      if (readable != null && readable.trim().isNotEmpty) return readable;
    }
    return _withoutPlusCode(trip.pickup);
  }

  /// The destination exactly as the driver chose it (the place they searched for or pinned) -
  /// already a real place name, so it is not geocoded again.
  static String destinationName(DriverTrip trip) =>
      _withoutPlusCode(trip.dropOff);

  static String _withoutPlusCode(String address) {
    final stripped = StreetPickupRepository.withoutPlusCode(address);
    return stripped.isEmpty ? address : stripped;
  }

  static String message(
    DriverTrip trip,
    DriverCopy l, {
    String? pickupName,
    String? destinationName,
  }) {
    final profile = DriverProfileService.instance.profile.value;
    final vehicle = [
      profile.vehicleModel,
      profile.vehicleColor,
      profile.vehiclePlateNumber,
    ].where((part) => part.trim().isNotEmpty).join(' • ');
    final started = DateFormat('HH:mm').format(trip.createdAt);
    return [
      l.t('🌧️ TheRain - Trip Details', '🌧️ TheRain - Détails de la course'),
      '',
      l.t(
        'Hello! Your driver has started your trip.',
        'Bonjour ! Votre chauffeur a démarré votre course.',
      ),
      '',
      if (profile.fullName.trim().isNotEmpty)
        '🚗 ${l.t('Driver', 'Chauffeur')}: ${profile.fullName}',
      if (profile.phone.trim().isNotEmpty)
        '📞 ${l.t('Driver Phone', 'Téléphone du chauffeur')}: ${profile.phone}',
      if (vehicle.isNotEmpty) '🚘 ${l.t('Vehicle', 'Véhicule')}: $vehicle',
      '⭐ ${l.t('Ride Type', 'Type de course')}: ${rideTypeLabel(trip.rideType, l)}',
      '',
      '📍 ${l.t('Pickup', 'Départ')}: ${pickupName ?? _withoutPlusCode(trip.pickup)}',
      '🏁 ${l.t('Destination', 'Destination')}: ${destinationName ?? StreetPickupShare.destinationName(trip)}',
      '💰 ${l.t('Estimated Fare', 'Tarif estimé')}: ${CurrencyFormatter.format(trip.fare)}',
      '',
      '🕐 ${l.t('Started at', 'Démarrée à')}: $started',
      '',
      l.t(
        '📲 Download TheRain: Coming soon on Play Store & App Store',
        "📲 Téléchargez TheRain : bientôt disponible sur le Play Store et l'App Store",
      ),
      '',
      l.t(
        'Ride safely with TheRain! 🌧️',
        'Voyagez en toute sécurité avec TheRain ! 🌧️',
      ),
    ].join('\n');
  }

  static String rideTypeLabel(String rideType, DriverCopy l) =>
      switch (rideType) {
        'comfort' => l.t('Comfort', 'Confort'),
        'vip' => l.t('VIP', 'VIP'),
        _ => l.t('Classic', 'Classique'),
      };

  /// The post-start "Share Trip Details" prompt, also behind the in-trip share button.
  static Future<void> offer(BuildContext context, DriverTrip trip) async {
    final l = DriverCopy.of(context);
    final phone = trip.riderPhone.trim();
    // Started now so the lookup usually finishes while the driver is still choosing a channel.
    final pickup = pickupName(trip);
    if (phone.isEmpty) {
      await Share.share(
        message(
          trip,
          l,
          pickupName: await pickup,
          destinationName: destinationName(trip),
        ),
      );
      return;
    }
    final choice = await showDialog<_ShareChannel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceFor(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l.t('📤 Share Trip Details', '📤 Partager les détails'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryFor(dialogContext),
          ),
        ),
        content: Text(
          l.t(
            'Share trip details with the passenger at $phone?',
            'Partager les détails de la course avec le passager au $phone ?',
          ),
          style: TextStyle(color: AppColors.textSecondaryFor(dialogContext)),
        ),
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.t('Skip', 'Passer')),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, _ShareChannel.sms),
            icon: const Icon(Icons.sms_outlined),
            label: Text(l.t('SMS', 'SMS')),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, _ShareChannel.whatsApp),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chat_rounded),
            label: Text(l.t('WhatsApp', 'WhatsApp')),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final text = message(
      trip,
      l,
      pickupName: await pickup,
      destinationName: destinationName(trip),
    );
    final digits = internationalDigits(phone);
    final opened = switch (choice) {
      _ShareChannel.whatsApp => await _launch(
        Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}'),
      ),
      _ShareChannel.sms => await _launch(
        Uri.parse('sms:+$digits?body=${Uri.encodeComponent(text)}'),
      ),
    };
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            choice == _ShareChannel.whatsApp
                ? l.t(
                    'Could not open WhatsApp. Try SMS instead.',
                    "Impossible d'ouvrir WhatsApp. Essayez plutôt par SMS.",
                  )
                : l.t(
                    'Could not open your messaging app.',
                    "Impossible d'ouvrir votre application de messagerie.",
                  ),
          ),
        ),
      );
    }
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

enum _ShareChannel { whatsApp, sms }
