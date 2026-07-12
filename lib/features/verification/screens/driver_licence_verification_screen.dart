import 'package:flutter/material.dart';

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

class DriverLicenceVerificationScreen extends StatefulWidget {
  const DriverLicenceVerificationScreen({super.key});

  @override
  State<DriverLicenceVerificationScreen> createState() =>
      _DriverLicenceVerificationScreenState();
}

class _DriverLicenceVerificationScreenState
    extends State<DriverLicenceVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _picker = StorageUploadService();
  final _storageService = FirebaseStorageService();
  final _verificationRepository = DriverVerificationRepository();
  bool _uploaded = false;
  bool _isUploading = false;
  double _progress = 0;
  String? _uploadError;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    final draft = RegistrationDraftService.instance.value;
    _number.text = draft.driverLicenceNumber;
    _expiryDate = draft.driverLicenceExpiryDate;
    _expiry.text = _formatDate(_expiryDate);
    _uploaded = draft.driverLicencePhotoPath != null;
    _loadSavedDraft();
  }

  Future<void> _loadSavedDraft() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    try {
      final verification = await _verificationRepository.getVerification(uid);
      if (!mounted || verification == null) return;
      final path = verification.licencePath;
      if (path == null) return;
      RegistrationDraftService.instance.draft.value = RegistrationDraftService
          .instance
          .value
          .copyWith(
            driverLicenceNumber: verification.licenceNumber,
            driverLicenceExpiryDate: verification.licenceExpiry,
            driverLicencePhotoPath: path,
          );
      setState(() {
        if (_number.text.isEmpty) {
          _number.text = verification.licenceNumber ?? '';
        }
        _expiryDate ??= verification.licenceExpiry;
        _expiry.text = _formatDate(_expiryDate);
        _uploaded = true;
      });
    } catch (_) {}
  }

  Future<void> _selectExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiryDate?.isAfter(today) == true
          ? _expiryDate!
          : today.add(const Duration(days: 365)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: DateTime(today.year + 20, 12, 31),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _expiryDate = selected;
      _expiry.text = _formatDate(selected);
    });
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
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('Choose an image smaller than 5MB.');
      }
      final extension = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw StateError('Use a JPG, JPEG, or PNG image.');
      }
      final uid = AuthService.instance.currentUserId;
      var savedPath = file.path;
      if (uid != null) {
        savedPath = await _storageService.uploadBytes(
          bytes: bytes,
          path: 'driver_verifications/$uid/driver_licence.jpg',
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        );
      } else if (mounted) {
        setState(() => _progress = 1);
      }
      RegistrationDraftService.instance.draft.value = RegistrationDraftService
          .instance
          .draft
          .value
          .copyWith(
            driverLicencePhotoPath: savedPath,
            driverLicencePhotoBytes: uid == null ? bytes : null,
            clearDriverLicenceBytes: uid != null,
          );
      if (mounted) {
        setState(() {
          _uploaded = true;
          _isUploading = false;
        });
      }
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
    final expiryDate = _expiryDate;
    if (expiryDate == null ||
        !expiryDate.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      _showError('Choose a licence expiry date in the future.');
      return;
    }
    final photoPath =
        RegistrationDraftService.instance.value.driverLicencePhotoPath;
    if (!_uploaded || photoPath == null) {
      _showError("Upload your driver's licence photo before continuing.");
      return;
    }
    RegistrationDraftService.instance.updateLicence(
      number: _number.text,
      expiryDate: expiryDate,
      photoPath: photoPath,
      photoBytes:
          RegistrationDraftService.instance.value.driverLicencePhotoBytes,
    );
    final uid = AuthService.instance.currentUserId;
    if (uid != null) {
      _verificationRepository.saveLicenceDraft(
        uid: uid,
        licenceNumber: _number.text,
        expiryDate: expiryDate,
        photoPath: photoPath,
      );
    }
    Navigator.pushNamed(
      context,
      _returnToReview ? RouteNames.review : RouteNames.selfie,
    );
  }

  bool get _returnToReview {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['returnToReview'] == true;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')} / '
        '${date.month.toString().padLeft(2, '0')} / ${date.year}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
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
                const StepIndicator(current: 3),
                const SizedBox(height: 18),
                Text(
                  "Driver's Licence",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Provide your valid licence details.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _number,
                  validator: (value) =>
                      Validators.required(value, "Driver's licence number"),
                  decoration: const InputDecoration(
                    labelText: "Driver's Licence Number",
                    hintText: 'e.g. ABC123456789',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _expiry,
                  readOnly: true,
                  onTap: _selectExpiry,
                  validator: (value) =>
                      Validators.required(value, 'Licence expiry date'),
                  decoration: const InputDecoration(
                    labelText: 'Licence Expiry Date',
                    hintText: 'DD / MM / YYYY',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                UploadBox(
                  title: "Upload Driver's Licence Photo",
                  subtitle: 'JPG or PNG - Max 5MB',
                  isUploaded: _uploaded,
                  isUploading: _isUploading,
                  progress: _progress,
                  errorText: _uploadError,
                  onTap: _pick,
                ),
                const SizedBox(height: 18),
                const AppCard(
                  color: AppColors.primarySoft,
                  child: Row(
                    children: [
                      IconWell(icon: Icons.verified_user_outlined),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Please ensure your licence is valid, not expired, '
                          'and every detail is readable.',
                        ),
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
