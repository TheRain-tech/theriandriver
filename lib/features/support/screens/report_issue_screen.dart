import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/driver_support_repository.dart';
import '../../../services/storage_upload_service.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/upload_box.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  // Values sent to the backend stay in English (business logic is
  // unchanged); only the on-screen label is translated via DriverCopy.t.
  static const _issueTypes = [
    ('Trip issue', 'Problème de course'),
    ('Payment issue', 'Problème de paiement'),
    ('App issue', "Problème avec l'application"),
    ('Rider issue', 'Problème avec le passager'),
    ('Other', 'Autre'),
  ];

  final _repository = DriverSupportRepository();
  final _upload = StorageUploadService();
  final _description = TextEditingController();
  String _issueType = 'Trip issue';
  String? _screenshotPath;
  bool _isSubmitting = false;
  double _uploadProgress = 0;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Describe the issue before submitting.',
              "Décrivez le problème avant d'envoyer.",
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
    });
    try {
      await _repository.createTicket(
        issueType: _issueType,
        description: _description.text.trim(),
        screenshotPath: _screenshotPath,
        onUploadProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Your report has been submitted. Our support team will review it.',
              "Votre signalement a été envoyé. Notre équipe d'assistance l'examinera.",
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
      title: copy.t('Report an Issue', 'Signaler un problème'),
      subtitle: copy.t(
        'What issue are you facing?',
        'Quel problème rencontrez-vous ?',
      ),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _issueType,
          decoration: InputDecoration(
            labelText: copy.t('Issue Type', 'Type de problème'),
          ),
          items: _issueTypes
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.$1,
                  child: Text(copy.t(entry.$1, entry.$2)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _issueType = value!),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _description,
          minLines: 6,
          maxLines: 8,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: copy.t('Description', 'Description'),
            hintText: copy.t(
              'Please describe the issue in detail...',
              'Veuillez décrire le problème en détail...',
            ),
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: 12),
        UploadBox(
          title: copy.t('Add Screenshot (Optional)', "Ajouter une capture d'écran (facultatif)"),
          subtitle: copy.t('Tap to upload', 'Appuyez pour télécharger'),
          icon: Icons.add_a_photo_outlined,
          isUploaded: _screenshotPath != null,
          isUploading: _isSubmitting && _screenshotPath != null,
          progress: _uploadProgress,
          onTap: () async {
            final image = await _upload.pickDocument();
            if (mounted && image != null) {
              setState(() => _screenshotPath = image.path);
            }
          },
        ),
        SizedBox(height: 20),
        PrimaryButton(
          label: copy.t('Submit Report', 'Envoyer le signalement'),
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
