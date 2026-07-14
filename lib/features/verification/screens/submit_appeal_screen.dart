import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/fleet_relations_repository.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_storage_service.dart';
import '../../../services/storage_upload_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/upload_box.dart';

/// Suspension appeal: Reason for Appeal, Explanation, Supporting Evidence
/// (upload documents/images), Submit → status becomes "Under Review". Goes
/// through node-api's appeal.service.js#createDriverSuspensionAppeal, which
/// notifies Regional + Super Admin and (on later approval) automatically
/// restores the driver's ACTIVE status/wallet/trips/dispatch eligibility.
class SubmitAppealScreen extends StatefulWidget {
  const SubmitAppealScreen({super.key});

  @override
  State<SubmitAppealScreen> createState() => _SubmitAppealScreenState();
}

class _SubmitAppealScreenState extends State<SubmitAppealScreen> {
  final _repository = FleetRelationsRepository();
  final _upload = StorageUploadService();
  final _storage = FirebaseStorageService();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _explanationController = TextEditingController();

  final List<String> _localImagePaths = [];
  bool _isSubmitting = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _reasonController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final image = await _upload.pickDocument();
    if (image != null && mounted) {
      setState(() => _localImagePaths.add(image.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
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
            'driver_suspension_appeals/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
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

      final explanation =
          'Reason for appeal: ${_reasonController.text.trim()}\n\n'
          '${_explanationController.text.trim()}';

      await _repository.submitSuspensionAppeal(
        driverId: uid,
        explanation: explanation,
        evidenceUrls: evidenceUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your appeal has been submitted and is now Under Review.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'We could not submit your appeal. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Submit Appeal',
    subtitle:
        'Explain why you believe this suspension should be reconsidered. '
        'TheRain Compliance & Safety Team will review your appeal.',
    children: [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Appeal',
                hintText: 'E.g. This suspension was made in error',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'A reason is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _explanationController,
              minLines: 6,
              maxLines: 10,
              maxLength: 3000,
              decoration: const InputDecoration(
                labelText: 'Explanation',
                hintText: 'Describe your side of the story in detail...',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Please explain your appeal'
                  : null,
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
                      onPressed: () =>
                          setState(() => _localImagePaths.remove(path)),
                    ),
                  ],
                ),
              ),
            UploadBox(
              title: 'Supporting Evidence (Optional)',
              subtitle: 'Upload documents or images — tap to add',
              icon: Icons.attach_file_rounded,
              isUploading: _isSubmitting && _localImagePaths.isNotEmpty,
              progress: _uploadProgress,
              onTap: _pickEvidence,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Submit Appeal',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ],
  );
}
