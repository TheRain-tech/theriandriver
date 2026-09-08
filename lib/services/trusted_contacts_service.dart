import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/trusted_contact.dart';

/// Device-only storage for a driver's trusted emergency contacts.
///
/// These are personal call shortcuts, not part of the driver's operational
/// profile, so - like [DriverPreferencesService] - they stay on-device
/// rather than syncing through node-api.
class TrustedContactsService {
  TrustedContactsService._();

  static final instance = TrustedContactsService._();

  static const maxContacts = 3;
  static const _storageKey = 'trusted_contacts';

  Future<List<TrustedContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => TrustedContact.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
    );
  }
}
