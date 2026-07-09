import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../services/registration_draft_service.dart';
import '../../../services/storage_upload_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/step_indicator.dart';
import '../../shared/widgets/upload_box.dart';

class NationalIdVerificationScreen extends StatefulWidget {
  const NationalIdVerificationScreen({super.key});

  @override
  State<NationalIdVerificationScreen> createState() =>
      _NationalIdVerificationScreenState();
}

class _NationalIdVerificationScreenState
    extends State<NationalIdVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _picker = StorageUploadService();
  bool _uploaded = false;
  bool _isUploading = false;
  double _progress = 0;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    final draft = RegistrationDraftService.instance.value;
    _number.text = draft.nationalIdNumber;
    _uploaded = draft.nationalIdPhotoPath != null;
  }

  Future<void> _pick() async {
    final file = await _picker.pickDocument();
    if (!mounted || file == null) return;
    setState(() {
      _isUploading = true;
      _progress = 0;
      _uploadError = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('The selected image is empty.');
      }
      if (mounted) setState(() => _progress = 1);
      RegistrationDraftService.instance.updateNationalId(
        number: _number.text,
        photoPath: file.path,
        photoBytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _uploaded = true;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final path = RegistrationDraftService.instance.value.nationalIdPhotoPath;
    if (!_uploaded || path == null) {
      _showError('Upload your National ID photo before continuing.');
      return;
    }
    RegistrationDraftService.instance.updateNationalId(
      number: _number.text,
      photoPath: path,
    );
    Navigator.pushNamed(context, RouteNames.licence);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StepIndicator(
                  current: 2,
                  labels: ['Account', 'ID', 'Licence', 'Selfie', 'Review'],
                ),
                const SizedBox(height: 26),
                Text(
                  'Verify National ID',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text('Upload a clear photo of your National ID.'),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _number,
                  validator: (value) =>
                      Validators.required(value, 'National ID number'),
                  decoration: const InputDecoration(
                    labelText: 'National ID Number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                UploadBox(
                  title: 'Upload National ID Photo',
                  subtitle: 'JPG or PNG - Max 5MB',
                  isUploaded: _uploaded,
                  isUploading: _isUploading,
                  progress: _progress,
                  errorText: _uploadError,
                  onTap: _pick,
                ),
                const SizedBox(height: 16),
                const AppCard(
                  color: AppColors.primarySoft,
                  child: Row(
                    children: [
                      IconWell(icon: Icons.shield_outlined),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Make sure all text is readable.\n'
                          'Avoid blurry or cropped images.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Preview', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      IconWell(
                        icon: _uploaded
                            ? Icons.check_circle_rounded
                            : Icons.image_outlined,
                        color: _uploaded ? AppColors.success : AppColors.slate,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _uploaded
                            ? 'National ID uploaded'
                            : 'No image uploaded yet',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: _uploaded && !_isUploading ? _continue : null,
                ),
                const SizedBox(height: 12),
                AppOutlineButton(
                  label: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
