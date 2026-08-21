import 'package:flutter/material.dart';

import '../../../core/utils/document_upload_policy.dart';
import '../../../core/utils/image_quality_validator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/driver_verification_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_storage_service.dart';
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
  final _idValidator = const CameroonIdValidator();
  final _storageService = FirebaseStorageService();
  final _verificationRepository = DriverVerificationRepository();
  bool _frontUploaded = false;
  bool _backUploaded = false;
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;
  double _frontProgress = 0;
  double _backProgress = 0;
  String? _frontUploadError;
  String? _backUploadError;

  @override
  void initState() {
    super.initState();
    RegistrationDraftService.instance.reconcileOwnership(
      AuthService.instance.currentUserId,
    );
    final draft = RegistrationDraftService.instance.value;
    _number.text = draft.nationalIdNumber;
    _frontUploaded = draft.nationalIdPhotoPath != null;
    _backUploaded = draft.nationalIdBackPhotoPath != null;
    _loadSavedDraft();
  }

  Future<void> _loadSavedDraft() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    try {
      final verification = await _verificationRepository.getVerification(uid);
      if (!mounted || verification == null) return;
      final frontPath = verification.nationalIdPath;
      final backPath = verification.nationalIdBackPath;
      if (frontPath == null && backPath == null) return;
      RegistrationDraftService.instance.updateNationalId(
        number: verification.nationalIdNumber ?? _number.text,
        frontPhotoPath: frontPath,
        backPhotoPath: backPath,
      );
      setState(() {
        if (_number.text.isEmpty) {
          _number.text = verification.nationalIdNumber ?? '';
        }
        _frontUploaded = frontPath != null;
        _backUploaded = backPath != null;
      });
    } catch (_) {}
  }

  Future<void> _pick({required bool front}) async {
    final file = await _picker.pickDocument(allowPdf: true);
    if (!mounted || file == null) return;

    final bytes = await file.readAsBytes();
    try {
      DocumentUploadPolicy.validate(fileName: file.name, bytes: bytes);
      if (!DocumentUploadPolicy.isPdf(file.name)) {
        final quality = ImageQualityValidator.validate(bytes);
        if (!quality.isValid) {
          _showError(quality.reason!);
          return;
        }
      }
    } on StateError catch (error) {
      _showError(error.message.toString());
      return;
    }

    final draft = RegistrationDraftService.instance.value;
    final otherPath = front
        ? draft.nationalIdBackPhotoPath
        : draft.nationalIdPhotoPath;
    if (otherPath != null && otherPath == file.path) {
      _showError('Use different photos for the front and back of your ID.');
      return;
    }
    setState(() {
      if (front) {
        _isUploadingFront = true;
        _frontProgress = 0;
        _frontUploadError = null;
      } else {
        _isUploadingBack = true;
        _backProgress = 0;
        _backUploadError = null;
      }
    });
    try {
      final uid = AuthService.instance.currentUserId;
      var savedPath = file.path;
      if (uid != null) {
        final extension = DocumentUploadPolicy.extensionFor(file.name);
        savedPath = await _storageService.uploadBytes(
          bytes: bytes,
          // storage.rules grants this driver write access under
          // driver-ids/{driverId}/... (deployed and live); driver_verifications is a real,
          // newer match block in the repo's storage.rules too, but keeping this on the
          // older, already-deployed path avoids depending on whichever storage rules
          // version happens to be live in production at any given moment. Extension/
          // contentType stay dynamic (not hardcoded to .jpg) so a PDF upload - this screen
          // explicitly allows one via _picker.pickDocument(allowPdf: true) - keeps its real
          // content type instead of being mislabeled as an image.
          path:
              'driver-ids/$uid/${front ? 'national_id_front' : 'national_id_back'}.$extension',
          contentType: DocumentUploadPolicy.contentTypeFor(file.name),
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              if (front) {
                _frontProgress = progress;
              } else {
                _backProgress = progress;
              }
            });
          },
        );
      } else if (mounted) {
        setState(() {
          if (front) {
            _frontProgress = 1;
          } else {
            _backProgress = 1;
          }
        });
      }
      final current = RegistrationDraftService.instance.value;
      RegistrationDraftService.instance.draft.value = current.copyWith(
        nationalIdNumber: _number.text,
        nationalIdPhotoPath: front ? savedPath : current.nationalIdPhotoPath,
        nationalIdPhotoBytes: front && uid == null ? bytes : null,
        nationalIdBackPhotoPath: front
            ? current.nationalIdBackPhotoPath
            : savedPath,
        nationalIdBackPhotoBytes: !front && uid == null ? bytes : null,
        clearNationalIdBytes: front && uid != null,
        clearNationalIdBackBytes: !front && uid != null,
      );
      final updated = RegistrationDraftService.instance.value;
      if (uid != null &&
          updated.nationalIdPhotoPath != null &&
          updated.nationalIdBackPhotoPath != null) {
        await _verificationRepository.saveNationalIdDraft(
          uid: uid,
          nationalIdNumber: _number.text,
          frontPath: updated.nationalIdPhotoPath!,
          backPath: updated.nationalIdBackPhotoPath!,
        );
      }
      if (!mounted) return;
      setState(() {
        if (front) {
          _frontUploaded = true;
          _isUploadingFront = false;
        } else {
          _backUploaded = true;
          _isUploadingBack = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (front) {
          _isUploadingFront = false;
          _frontUploadError = _describeUploadError(error);
        } else {
          _isUploadingBack = false;
          _backUploadError = _describeUploadError(error);
        }
      });
    }
  }

  /// [FirebaseStorageService] already translates every storage error it
  /// throws into a friendly [StateError] message - this only exists so a
  /// raw, technical exception (e.g. a Firebase error that escapes some
  /// other call in this method) can never reach the screen as-is instead
  /// of a message a driver can act on.
  String _describeUploadError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return 'The document upload failed. Please try again.';
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final draft = RegistrationDraftService.instance.value;
    final frontPath = draft.nationalIdPhotoPath;
    final backPath = draft.nationalIdBackPhotoPath;
    if (!_frontUploaded || frontPath == null) {
      _showError('Upload your National ID front before continuing.');
      return;
    }
    if (!_backUploaded || backPath == null) {
      _showError('Upload your National ID back before continuing.');
      return;
    }
    if (frontPath == backPath) {
      _showError('Use different photos for the front and back of your ID.');
      return;
    }
    RegistrationDraftService.instance.updateNationalId(
      number: _idValidator.normalize(_number.text),
      frontPhotoPath: frontPath,
      backPhotoPath: backPath,
    );
    Navigator.pushNamed(
      context,
      _returnToReview ? RouteNames.review : RouteNames.licence,
    );
  }

  bool get _returnToReview {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['returnToReview'] == true;
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
                SizedBox(height: 26),
                Text(
                  'Verify National ID',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 6),
                Text(
                  'Upload clear front and back images or PDF files of your National ID.',
                ),
                SizedBox(height: 22),
                TextFormField(
                  controller: _number,
                  validator: _idValidator.call,
                  decoration: const InputDecoration(
                    labelText: 'National ID Number',
                    helperText:
                        'Enter it exactly as printed. Spaces and hyphens are accepted.',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                SizedBox(height: 18),
                UploadBox(
                  title: 'Upload National ID Front',
                  subtitle: 'Image or PDF - Max 10 MB',
                  isUploaded: _frontUploaded,
                  isUploading: _isUploadingFront,
                  progress: _frontProgress,
                  errorText: _frontUploadError,
                  onTap: () => _pick(front: true),
                ),
                SizedBox(height: 14),
                UploadBox(
                  title: 'Upload National ID Back',
                  subtitle: 'Image or PDF - Max 10 MB',
                  isUploaded: _backUploaded,
                  isUploading: _isUploadingBack,
                  progress: _backProgress,
                  errorText: _backUploadError,
                  onTap: () => _pick(front: false),
                ),
                SizedBox(height: 16),
                AppCard(
                  color: AppColors.primarySoftFor(context),
                  child: Row(
                    children: [
                      IconWell(icon: Icons.shield_outlined),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Make sure all text is readable.\n'
                          'Make sure the whole card is visible, readable, and not blurry.',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                Text('Preview', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      IconWell(icon: Icons.badge_outlined),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _frontUploaded && _backUploaded
                              ? 'Front and back attached'
                              : 'Attach both front and back documents',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22),
                PrimaryButton(
                  label: 'Continue',
                  onPressed:
                      _frontUploaded &&
                          _backUploaded &&
                          !_isUploadingFront &&
                          !_isUploadingBack
                      ? _continue
                      : null,
                ),
                SizedBox(height: 12),
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
