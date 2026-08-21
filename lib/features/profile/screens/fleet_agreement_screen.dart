import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/fleet_agreement.dart';
import '../../../data/repositories/fleet_relations_repository.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// Fleet drivers only. Fleet Name, Driver Name, Agreement Status, Agreement
/// Start Date, Driver ID, Fleet ID, Contract Summary, "View Full Agreement" /
/// "Contact Fleet". Sourced from node-api's driver.service.js
/// #getDriverFleetAgreement (driver_fleet_agreements collection).
class FleetAgreementScreen extends StatefulWidget {
  const FleetAgreementScreen({super.key});

  @override
  State<FleetAgreementScreen> createState() => _FleetAgreementScreenState();
}

class _FleetAgreementScreenState extends State<FleetAgreementScreen> {
  final _repository = FleetRelationsRepository();
  late Future<FleetAgreement?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<FleetAgreement?> _load() {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return Future.value(null);
    return _repository.getFleetAgreement(uid);
  }

  Future<void> _contactFleet() async {
    final fleetInfo = DriverProfileService.instance.fleetInfo.value;
    final phone = fleetInfo?.phoneNumber;
    final email = fleetInfo?.email;
    Uri? uri;
    if (phone != null && phone.trim().isNotEmpty) {
      uri = Uri(scheme: 'tel', path: phone.trim());
    } else if (email != null && email.trim().isNotEmpty) {
      uri = Uri(scheme: 'mailto', path: email.trim());
    }
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fleet contact details are available yet.'),
        ),
      );
      return;
    }
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open your device dialer/mail app.'),
        ),
      );
    }
  }

  void _viewFullAgreement(FleetAgreement agreement) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Text(
                'TheRain Fleet-Driver Agreement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 4),
              Text(
                'Agreement ID: ${agreement.agreementId}',
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 16),
              Text(agreement.contractSummary, style: TextStyle(height: 1.5)),
              SizedBox(height: 20),
              Text(
                'For the complete signed agreement document, contact your '
                'fleet owner or TheRain support.',
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Fleet Agreement',
    children: [
      FutureBuilder<FleetAgreement?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'We could not load your fleet agreement.';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final agreement = snapshot.data;
          if (agreement == null) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No fleet agreement found for your account.'),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            agreement.fleetName ?? 'Fleet Partner',
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: agreement.status == 'ACTIVE'
                              ? 'Active'
                              : agreement.status,
                          tone: agreement.status == 'ACTIVE'
                              ? BadgeTone.success
                              : BadgeTone.warning,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    LabeledValue(
                      label: 'Driver Name',
                      value: agreement.driverName ?? '—',
                    ),
                    SizedBox(height: 12),
                    LabeledValue(
                      label: 'Agreement Start Date',
                      value: agreement.agreementStartDate == null
                          ? '—'
                          : DateFormatter.short(agreement.agreementStartDate!),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: LabeledValue(
                            label: 'Driver ID',
                            value: agreement.driverId,
                          ),
                        ),
                        Expanded(
                          child: LabeledValue(
                            label: 'Fleet ID',
                            value: agreement.fleetId,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contract Summary',
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      agreement.contractSummary,
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              AppOutlineButton(
                label: 'View Full Agreement',
                icon: Icons.description_outlined,
                onPressed: () => _viewFullAgreement(agreement),
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _contactFleet,
                icon: Icon(Icons.call_outlined),
                label: Text('Contact Fleet'),
              ),
            ],
          );
        },
      ),
    ],
  );
}
