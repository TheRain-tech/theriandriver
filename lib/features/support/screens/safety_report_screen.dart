import '../../../core/localization/driver_copy.dart';
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
    'SAFETY_CONCERN': ('Safety concern', 'Problème de sécurité'),
    'ROAD_ACCIDENT': ('Road accident', 'Accident de la route'),
    'VEHICLE_BREAKDOWN': ('Vehicle breakdown', 'Panne de véhicule'),
    'FLEET_COMPLAINT': ('Fleet issue', 'Problème lié à la flotte'),
    'FRAUD_REPORT': ('Fraud report', 'Signalement de fraude'),
    'LOST_PROPERTY': ('Lost property', 'Objet perdu'),
  };

  final _repository = DriverIncidentRepository();
  final _description = TextEditingController();
  String _type = 'SAFETY_CONCERN';
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Describe what happened before submitting.',
              "Décrivez ce qui s'est passé avant d'envoyer.",
            ),
          ),
        ),
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
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Your safety report has been sent to TheRain Central Command.',
              'Votre signalement de sécurité a été transmis au centre de commandement TheRain.',
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'We could not submit your report. Please try again.',
              "Nous n'avons pas pu envoyer votre signalement. Veuillez réessayer.",
            ),
          ),
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
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return FeatureScaffold(
      title: copy.t('Safety & Security', 'Sécurité et sûreté'),
      subtitle: copy.t(
        'Report a safety concern to TheRain Central Command',
        'Signalez un problème de sécurité au centre de commandement TheRain',
      ),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: InputDecoration(
            labelText: copy.t('Report type', 'Type de signalement'),
          ),
          items: _types.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(copy.t(entry.value.$1, entry.value.$2)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _type = value!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          minLines: 6,
          maxLines: 8,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: copy.t('Description', 'Description'),
            hintText: copy.t(
              'Please describe what happened in detail...',
              'Veuillez décrire en détail ce qui s\'est passé...',
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: copy.t('Submit Safety Report', 'Envoyer le signalement'),
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
