import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/danger_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/fleet_report.dart';
import '../../../data/repositories/fleet_relations_repository.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_storage_service.dart';
import '../../../services/storage_upload_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/upload_box.dart';

/// Fleet drivers ONLY (hidden entirely for TheRain-direct drivers — see
/// driver_profile_screen.dart, which only shows the entry point to this
/// screen when profile.isFleetDriver). Reasons: Salary/commission dispute;
/// Unsafe working conditions; Harassment/abuse/discrimination; Fraudulent/
/// illegal activity; Other+description. Notifies Regional + Super Admin,
/// stored in driver_fleet_reports, driver can track status here afterwards.
class ReportFleetScreen extends StatefulWidget {
  const ReportFleetScreen({super.key});

  @override
  State<ReportFleetScreen> createState() => _ReportFleetScreenState();
}

class _ReportFleetScreenState extends State<ReportFleetScreen> {
  final _repository = FleetRelationsRepository();
  final _upload = StorageUploadService();
  final _storage = FirebaseStorageService();
  final _descriptionController = TextEditingController();

  FleetReportReason _reason = FleetReportReason.salaryCommissionDispute;
  final List<String> _localImagePaths = [];
  bool _isSubmitting = false;
  double _uploadProgress = 0;
  late Future<List<FleetReport>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<FleetReport>> _loadHistory() {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return Future.value(const []);
    return _repository.listFleetReports(uid);
  }

  Future<void> _pickEvidence() async {
    final image = await _upload.pickDocument();
    if (image != null && mounted) {
      setState(() => _localImagePaths.add(image.path));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_reason == FleetReportReason.other &&
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the issue when reason is "Other".'),
        ),
      );
      return;
    }
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
    });

    try {
      final evidenceUrls = <String>[];
      for (var i = 0; i < _localImagePaths.length; i++) {
        final path =
            'driver_fleet_reports/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await _storage.uploadFile(
          file: XFile(_localImagePaths[i]),
          path: path,
          onProgress: (progress) {
            if (mounted) {
              setState(
                () => _uploadProgress =
                    (i + progress) / (_localImagePaths.length),
              );
            }
          },
        );
        evidenceUrls.add(await _storage.getDownloadUrl(path));
      }

      await _repository.submitFleetReport(
        driverId: uid,
        reasonApiValue: _reason.apiValue,
        description: _descriptionController.text.trim(),
        evidenceUrls: evidenceUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your report has been submitted to TheRain Compliance. '
            'You can track its status below.',
          ),
        ),
      );
      _descriptionController.clear();
      setState(() {
        _localImagePaths.clear();
        _isSubmitting = false;
        _historyFuture = _loadHistory();
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'We could not submit your report. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Report Fleet',
    subtitle:
        'Tell TheRain Compliance & Safety Team about an issue with your fleet.',
    children: [
      DropdownButtonFormField<FleetReportReason>(
        initialValue: _reason,
        decoration: const InputDecoration(labelText: 'Reason'),
        items: FleetReportReason.values
            .map(
              (reason) =>
                  DropdownMenuItem(value: reason, child: Text(reason.label)),
            )
            .toList(),
        onChanged: (value) => setState(() => _reason = value ?? _reason),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _descriptionController,
        minLines: 5,
        maxLines: 8,
        maxLength: 1000,
        decoration: InputDecoration(
          labelText: _reason == FleetReportReason.other
              ? 'Description (required)'
              : 'Description (optional)',
          hintText: 'Please describe what happened in detail...',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 8),
      for (final path in _localImagePaths)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(path.split('/').last)),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _localImagePaths.remove(path)),
              ),
            ],
          ),
        ),
      UploadBox(
        title: 'Add Photo/Document (Optional)',
        subtitle: 'Attach supporting evidence — tap to add',
        icon: Icons.attach_file_rounded,
        isUploading: _isSubmitting && _localImagePaths.isNotEmpty,
        progress: _uploadProgress,
        onTap: _pickEvidence,
      ),
      const SizedBox(height: 20),
      DangerButton(
        label: 'Submit Report',
        isLoading: _isSubmitting,
        onPressed: _submit,
      ),
      const SizedBox(height: 28),
      const SectionHeader(title: 'Your Reports'),
      const SizedBox(height: 10),
      FutureBuilder<List<FleetReport>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final reports = snapshot.data ?? const [];
          if (reports.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'You have not filed any fleet reports.',
                style: TextStyle(color: AppColors.slate),
              ),
            );
          }
          return Column(
            children: [
              for (final report in reports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.reasonLabel,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Filed ${DateFormatter.short(report.createdAt)} • ID ${report.id}',
                                style: const TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: _statusLabel(report.status),
                          tone: _statusTone(report.status),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  String _statusLabel(String status) => switch (status) {
    'PENDING' => 'Pending',
    'UNDER_REVIEW' => 'Under Review',
    'RESOLVED' => 'Resolved',
    'CLOSED' => 'Closed',
    _ => status,
  };

  BadgeTone _statusTone(String status) => switch (status) {
    'RESOLVED' => BadgeTone.success,
    'UNDER_REVIEW' => BadgeTone.info,
    'CLOSED' => BadgeTone.neutral,
    _ => BadgeTone.warning,
  };
}
