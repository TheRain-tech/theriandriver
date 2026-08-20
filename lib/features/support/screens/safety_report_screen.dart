import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/driver_incident_repository.dart';
import '../../shared/widgets/feature_templates.dart';

/// Distinct from Report an Issue (DriverSupportRepository -> support_tickets,
/// general help-desk categories like Trip/Payment/App) - this feeds the real
/// Trust & Safety incident system (DriverIncidentRepository -> POST
/// /api/incidents) so a genuine safety concern is visible to Central Command,
/// not just the support queue. Reachable for both fleet-linked and
/// independent drivers alike - DriverIncidentRepository already includes
/// fleetId when present and simply omits it otherwise, so nothing here is
/// conditioned on fleet status.
class SafetyReportScreen extends StatefulWidget {
  const SafetyReportScreen({super.key});

  @override
  State<SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends State<SafetyReportScreen> {
  static const _types = {
    'SAFETY_CONCERN': 'Safety concern',
    'ROAD_ACCIDENT': 'Road accident',
    'VEHICLE_BREAKDOWN': 'Vehicle breakdown',
    'FLEET_COMPLAINT': 'Fleet issue',
    'FRAUD_REPORT': 'Fraud report',
    'LOST_PROPERTY': 'Lost property',
  };

  final _repository = DriverIncidentRepository();
  final _description = TextEditingController();
  String _type = 'SAFETY_CONCERN';
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe what happened before submitting.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _repository.createSafetyReport(
        type: _type,
        description: _description.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your safety report has been sent to TheRain Central Command.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not submit your report. Please try again.'),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Safety & Security',
    subtitle: 'Report a safety concern to TheRain Central Command',
    children: [
      DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Report type'),
        items: _types.entries
            .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: (value) => setState(() => _type = value!),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _description,
        minLines: 6,
        maxLines: 8,
        maxLength: 2000,
        decoration: const InputDecoration(
          labelText: 'Description',
          hintText: 'Please describe what happened in detail...',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        label: 'Submit Safety Report',
        isLoading: _isSubmitting,
        onPressed: _submit,
      ),
    ],
  );
}
