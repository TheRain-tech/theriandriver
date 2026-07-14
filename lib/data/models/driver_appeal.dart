/// A driver's suspension appeal (node-api's appeal.service.js
/// #createDriverSuspensionAppeal / getLatestDriverAppeal). Status vocabulary:
/// PENDING -> UNDER_REVIEW -> APPROVED | REJECTED | MORE_INFO_REQUIRED.
class DriverAppeal {
  const DriverAppeal({
    required this.id,
    required this.status,
    required this.explanation,
    required this.submittedAt,
    this.decisionNotes,
    this.decidedAt,
  });

  final String id;
  final String status;
  final String explanation;
  final DateTime submittedAt;
  final String? decisionNotes;
  final DateTime? decidedAt;

  String get displayStatus => switch (status) {
    'PENDING' => 'Under Review',
    'UNDER_REVIEW' => 'Under Review',
    'APPROVED' => 'Approved',
    'REJECTED' => 'Rejected',
    'MORE_INFO_REQUIRED' => 'More Information Requested',
    _ => status,
  };

  factory DriverAppeal.fromJson(Map<String, dynamic> json) => DriverAppeal(
    id: json['id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'PENDING',
    explanation: json['explanation']?.toString() ?? '',
    submittedAt: _date(json['createdAt']) ?? DateTime.now(),
    decisionNotes: json['decisionNotes']?.toString(),
    decidedAt: _date(json['decidedAt']),
  );

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds as num).toInt() * 1000,
        );
      }
    }
    return null;
  }
}
