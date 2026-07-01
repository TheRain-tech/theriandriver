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
        const SnackBar(content: Text('Describe the issue before submitting.')),
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
        const SnackBar(
          content: Text(
            'Your report has been submitted. Our support team will review it.',
          ),
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
    title: 'Report an Issue',
    subtitle: 'What issue are you facing?',
    children: [
      DropdownButtonFormField<String>(
        initialValue: _issueType,
        decoration: const InputDecoration(labelText: 'Issue Type'),
        items:
            const [
                  'Trip issue',
                  'Payment issue',
                  'App issue',
                  'Rider issue',
                  'Other',
                ]
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
        onChanged: (value) => setState(() => _issueType = value!),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _description,
        minLines: 6,
        maxLines: 8,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Description',
          hintText: 'Please describe the issue in detail...',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      UploadBox(
        title: 'Add Screenshot (Optional)',
        subtitle: 'Tap to upload',
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
      const SizedBox(height: 20),
      PrimaryButton(
        label: 'Submit Report',
        isLoading: _isSubmitting,
        onPressed: _submit,
      ),
    ],
  );
}
