import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/driver_trip.dart';
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

  static String message(DriverTrip trip, DriverCopy l) {
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
      '📍 ${l.t('Pickup', 'Départ')}: ${trip.pickup}',
      '🏁 ${l.t('Destination', 'Destination')}: ${trip.dropOff}',
      '💰 ${l.t('Estimated Fare', 'Tarif estimé')}: ${CurrencyFormatter.format(trip.fare)}',
      '',
      '🕐 ${l.t('Started', 'Démarrée')}: $started',
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
    if (phone.isEmpty) {
      await Share.share(message(trip, l));
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
    final text = message(trip, l);
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
