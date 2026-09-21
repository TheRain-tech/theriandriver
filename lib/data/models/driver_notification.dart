import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/driver_preferences_service.dart';

class DriverNotification {
  const DriverNotification({
    required this.id,
    required this.driverId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String driverId;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;

  factory DriverNotification.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return DriverNotification(
      id: documentId,
      // node-api's notification.service.js#createNotification is the real
      // writer for every server-driven notification (earnings, payment
      // requests, suspension, appeals, fleet reports, ...) and stores
      // `recipientId`/`isRead` — `userId`/`read` are kept as a fallback only
      // for any legacy doc this app itself may have written directly.
      driverId:
          map['recipientId']?.toString() ?? map['userId']?.toString() ?? '',
      title: _localized(map, 'title') ?? map['title']?.toString() ?? '',
      message: _localized(map, 'body') ?? map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'system',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] == true || map['read'] == true,
    );
  }

  /// The backend stores both languages of a message (`translations.en/fr`), so the inbox follows
  /// the driver's current language even for notifications received before they switched.
  /// Older notifications without translations keep the text they were stored with.
  static String? _localized(Map<String, dynamic> map, String field) {
    final translations = map['translations'];
    if (translations is! Map) return null;
    final code =
        DriverPreferencesService.instance.preferences.value.locale.languageCode
                .toLowerCase() ==
            'fr'
        ? 'fr'
        : 'en';
    final entry = translations[code];
    if (entry is! Map) return null;
    final value = entry[field]?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  factory DriverNotification.fromJson(Map<String, dynamic> json) =>
      DriverNotification(
        id: json['id'] as String,
        driverId: json['driverId'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'userId': driverId,
    'title': title,
    'body': message,
    'type': type,
    'createdAt': Timestamp.fromDate(createdAt),
    'read': isRead,
  };
}
