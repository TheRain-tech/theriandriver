import '../../services/api_client.dart';
import '../models/driver_appeal.dart';
import '../models/fleet_agreement.dart';
import '../models/fleet_report.dart';

/// Fleet Agreement, Report Fleet, and suspension-appeal surfaces — all go
/// through node-api's validated service functions (driver.service.js /
/// appeal.service.js) rather than direct Firestore writes, since each one
/// has server-side business rules (fleet-driver-only, one appeal at a time,
/// notifies Regional + Super Admin, etc.) that must not be bypassable from
/// the client.
class FleetRelationsRepository {
  FleetRelationsRepository({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<FleetAgreement?> getFleetAgreement(String driverId) async {
    final data = await _client.get('/api/drivers/$driverId/fleet-agreement');
    if (data is! Map<String, dynamic>) return null;
    if (data.isEmpty) return null;
    return FleetAgreement.fromJson(data);
  }

  Future<FleetReport> submitFleetReport({
    required String driverId,
    required String reasonApiValue,
    String? description,
    List<String> evidenceUrls = const [],
  }) async {
    final data = await _client.post(
      '/api/drivers/$driverId/report-fleet',
      body: {
        'reason': reasonApiValue,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (evidenceUrls.isNotEmpty) 'evidenceUrls': evidenceUrls,
      },
    );
    return FleetReport.fromJson(data as Map<String, dynamic>);
  }

  Future<List<FleetReport>> listFleetReports(String driverId) async {
    final data = await _client.get('/api/drivers/$driverId/fleet-reports');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (row) =>
              FleetReport.fromJson(row.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> submitSuspensionAppeal({
    required String driverId,
    required String explanation,
    List<String> evidenceUrls = const [],
  }) async {
    await _client.post(
      '/api/drivers/$driverId/appeal',
      body: {
        'explanation': explanation,
        if (evidenceUrls.isNotEmpty) 'evidenceUrls': evidenceUrls,
      },
    );
  }

  Future<DriverAppeal?> getLatestAppeal(String driverId) async {
    final data = await _client.get('/api/drivers/$driverId/appeal-status');
    if (data is! Map<String, dynamic> || data.isEmpty) return null;
    return DriverAppeal.fromJson(data);
  }
}
