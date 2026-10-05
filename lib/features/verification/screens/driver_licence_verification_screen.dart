import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/document_upload_policy.dart';
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
    RegistrationDraftService.instance.reconcileOwnership(
      AuthService.instance.currentUserId,
    );
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
    final file = await _picker.pickDocument(allowPdf: true);
    if (!mounted || file == null) return;

    final bytes = await file.readAsBytes();
    final fileName = file.name;
    try {
      DocumentUploadPolicy.validate(fileName: fileName, bytes: bytes);
    } on StateError catch (error) {
      _showError(error.message.toString());
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
      _uploadError = null;
    });
    try {
      final uid = AuthService.instance.currentUserId;
      var savedPath = file.path;
      if (uid != null) {
        final extension = DocumentUploadPolicy.extensionFor(fileName);
        savedPath = await _storageService.uploadBytes(
          bytes: bytes,
          // storage.rules grants this driver write access under
          // driver-licenses/{driverId}/... (deployed and live) - kept dynamic
          // extension/contentType (not hardcoded .jpg) so a PDF upload keeps its
          // real content type. See the identical note in
          // national_id_verification_screen.dart.
          path: 'driver-licenses/$uid/driver_licence.$extension',
          contentType: DocumentUploadPolicy.contentTypeFor(fileName),
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
      _showError(
        DriverCopy.current.t(
          'Choose a licence expiry date in the future.',
          'Choisissez une date d\'expiration de permis dans le futur.',
        ),
      );
      return;
    }
    final photoPath =
        RegistrationDraftService.instance.value.driverLicencePhotoPath;
    if (!_uploaded || photoPath == null) {
      _showError(
        DriverCopy.current.t(
          "Upload your driver's licence before continuing.",
          'Téléversez votre permis de conduire avant de continuer.',
        ),
      );
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
    final l = DriverCopy.of(context);
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
                SizedBox(height: 18),
                Text(
                  l.t("Driver's Licence", 'Permis de conduire'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 5),
                Text(
                  l.t(
                    'Provide your valid licence details.',
                    'Fournissez les détails de votre permis valide.',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _number,
                  validator: (value) => Validators.required(
                    value,
                    l.t("Driver's licence number", 'Numéro de permis de conduire'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t(
                      "Driver's Licence Number",
                      'Numéro de permis de conduire',
                    ),
                    hintText: l.t('e.g. ABC123456789', 'ex. ABC123456789'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _expiry,
                  readOnly: true,
                  onTap: _selectExpiry,
                  validator: (value) => Validators.required(
                    value,
                    l.t('Licence expiry date', 'Date d\'expiration du permis'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t(
                      'Licence Expiry Date',
                      'Date d\'expiration du permis',
                    ),
                    hintText: l.t('DD / MM / YYYY', 'JJ / MM / AAAA'),
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                SizedBox(height: 18),
                UploadBox(
                  title: l.t(
                    "Upload Driver's Licence",
                    'Téléverser le permis de conduire',
                  ),
                  subtitle: l.t(
                    'Images up to 100 MB. PDFs up to 10 MB.',
                    'Images jusqu\'à 100 Mo. PDF jusqu\'à 10 Mo.',
                  ),
                  isUploaded: _uploaded,
                  isUploading: _isUploading,
                  progress: _progress,
                  errorText: _uploadError,
                  onTap: _pick,
                ),
                SizedBox(height: 18),
                AppCard(
                  color: AppColors.primarySoftFor(context),
                  child: Row(
                    children: [
                      IconWell(icon: Icons.verified_user_outlined),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l.t(
                            'Please ensure your licence is valid, not expired, '
                                'and every detail is readable.',
                            'Veuillez vous assurer que votre permis est valide, non expiré, '
                                'et que chaque détail est lisible.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22),
                PrimaryButton(
                  label: l.t('Continue', 'Continuer'),
                  onPressed: _uploaded && !_isUploading ? _continue : null,
                ),
                SizedBox(height: 12),
                AppOutlineButton(
                  label: l.t('Back', 'Retour'),
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
