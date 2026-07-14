import 'package:cloud_firestore/cloud_firestore.dart';

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
      title: map['title']?.toString() ?? '',
      message: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'system',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] == true || map['read'] == true,
    );
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
