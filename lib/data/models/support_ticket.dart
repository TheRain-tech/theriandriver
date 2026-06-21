import 'app_enums.dart';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.driverId,
    required this.issueType,
    required this.description,
    required this.status,
    required this.createdAt,
    this.screenshotPath,
    this.updatedAt,
  });

  final String id;
  final String driverId;
  final String issueType;
  final String description;
  final SupportTicketStatus status;
  final DateTime createdAt;
  final String? screenshotPath;
  final DateTime? updatedAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'] as String,
    driverId: json['driverId'] as String,
    issueType: json['issueType'] as String,
    description: json['description'] as String,
    status: enumByName(
      SupportTicketStatus.values,
      json['status'],
      SupportTicketStatus.open,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    screenshotPath: json['screenshotPath'] as String?,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'issueType': issueType,
    'description': description,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'screenshotPath': screenshotPath,
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
