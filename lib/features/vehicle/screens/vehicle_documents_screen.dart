import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_document.dart';
import '../../../data/repositories/driver_vehicle_repository.dart';
import '../../../services/storage_upload_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// Every document type this app expects a driver to have on file. Same strings used both as
/// the checklist below and as the upload sheet's type list, so there is exactly one place that
/// defines "what documents a driver needs" - the checklist can never fall out of sync with what
/// the upload flow lets someone pick.
const _requiredDocumentTypes = [
  'National ID',
  'Driver licence',
  'Insurance',
  'Road Licence',
  'Fitness Certificate',
  'Vehicle Photos',
];

String _documentStatusLabel(DocumentStatus status, DriverCopy l) => switch (status) {
  DocumentStatus.notUploaded => l.t('Not uploaded', 'Non téléversé'),
  DocumentStatus.uploaded => l.t('Uploaded', 'Téléversé'),
  DocumentStatus.pending => l.t('Pending', 'En attente'),
  DocumentStatus.verified => l.t('Verified', 'Vérifié'),
  DocumentStatus.rejected => l.t('Rejected', 'Rejeté'),
};

class VehicleDocumentsScreen extends StatefulWidget {
  const VehicleDocumentsScreen({super.key});

  @override
  State<VehicleDocumentsScreen> createState() => _VehicleDocumentsScreenState();
}

class _VehicleDocumentsScreenState extends State<VehicleDocumentsScreen> {
  final _repository = DriverVehicleRepository();
  final _uploadService = StorageUploadService();
  late Future<List<DriverDocument>> _documentsFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    _documentsFuture = _repository.getDocuments();
  }

  void _retry() {
    setState(() {
      _loadDocuments();
    });
  }

  /// Latest document on file for [type] (case-insensitive - the upload dialog's own option list
  /// mixes "Road Licence" and "Driver licence" casing, so an exact match would be fragile), or
  /// null if the driver has never uploaded one. When more than one exists for the same type, the
  /// most recently updated wins - a driver replacing a rejected document shouldn't have the old
  /// rejected row shadow the new one.
  DriverDocument? _latestFor(String type, List<DriverDocument> documents) {
    final matches =
        documents
            .where((doc) => doc.type.toLowerCase() == type.toLowerCase())
            .toList()
          ..sort((a, b) {
            final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
    return matches.isEmpty ? null : matches.first;
  }

  // _requiredDocumentTypes are also the dropdown's own values, the _icon() switch key, and the
  // exact string sent to _repository.uploadDocument - so, like driver_dashboard_screen.dart's
  // _blockedReason/_blockedReasonDisplay split, only the label shown here is translated; the type
  // identity itself never changes with locale.
  String _documentTypeLabel(String type, DriverCopy l) => switch (type) {
    'National ID' => l.t('National ID', "Carte d'identité nationale"),
    'Driver licence' => l.t('Driver licence', 'Permis de conduire'),
    'Insurance' => l.t('Insurance', 'Assurance'),
    'Road Licence' => l.t('Road Licence', 'Carte grise'),
    'Fitness Certificate' => l.t('Fitness Certificate', 'Certificat de visite technique'),
    'Vehicle Photos' => l.t('Vehicle Photos', 'Photos du véhicule'),
    _ => type,
  };

  void _showUploadDialog({String? presetType}) {
    String selectedType = presetType ?? _requiredDocumentTypes.first;
    XFile? pickedFile;
    DateTime? selectedExpiry;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final l = DriverCopy.of(context);
            return Container(
              decoration: BoxDecoration(
                color: AppColors.elevatedSurfaceFor(context),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 12,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: AppColors.borderFor(context),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Text(
                          l.t('Upload Document', 'Téléverser un document'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.textPrimaryFor(context),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: InputDecoration(
                            labelText: l.t('Document Type', 'Type de document'),
                          ),
                          items: _requiredDocumentTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(_documentTypeLabel(type, l)),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedType = val);
                            }
                          },
                        ),
                        SizedBox(height: 14),
                        ListTile(
                          leading: Icon(
                            Icons.photo_library_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            pickedFile == null
                                ? l.t('Select image or PDF', 'Sélectionner une image ou un PDF')
                                : l.t('Document selected', 'Document sélectionné'),
                          ),
                          subtitle: Text(
                            pickedFile == null
                                ? l.t(
                                    'JPG, PNG, WEBP, HEIC, HEIF, or PDF - Max 10 MB',
                                    'JPG, PNG, WEBP, HEIC, HEIF ou PDF - 10 Mo max',
                                  )
                                : pickedFile!.name,
                          ),
                          trailing: pickedFile != null
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                )
                              : Icon(Icons.chevron_right),
                          onTap: () async {
                            final file = await _uploadService.pickDocument(
                              allowPdf: true,
                            );
                            if (file != null) {
                              setModalState(() => pickedFile = file);
                            }
                          },
                        ),
                        SizedBox(height: 14),
                        ListTile(
                          leading: Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            selectedExpiry == null
                                ? l.t('Expiry Date (Optional)', "Date d'expiration (facultatif)")
                                : l.t('Expiry Date', "Date d'expiration"),
                          ),
                          subtitle: Text(
                            selectedExpiry == null
                                ? l.t('Not set', 'Non définie')
                                : '${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}',
                          ),
                          trailing: Icon(Icons.date_range_outlined),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (picked != null) {
                              setModalState(() => selectedExpiry = picked);
                            }
                          },
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: pickedFile == null || _isUploading
                              ? null
                              : () async {
                                  Navigator.pop(context); // Close sheet
                                  setState(() {
                                    _isUploading = true;
                                  });
                                  try {
                                    await _repository.uploadDocument(
                                      type: selectedType,
                                      file: pickedFile!,
                                      expiresAt: selectedExpiry,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            DriverCopy.current.t(
                                              'Document uploaded successfully.',
                                              'Document téléversé avec succès.',
                                            ),
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                      _retry();
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error.toString().replaceFirst(
                                              'Bad state: ',
                                              '',
                                            ),
                                          ),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isUploading = false;
                                      });
                                    }
                                  }
                                },
                          child: Text(l.t('Upload', 'Téléverser')),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DriverDocument>>(
    future: _documentsFuture,
    builder: (context, snapshot) {
      final l = DriverCopy.of(context);
      final documents = snapshot.data ?? const <DriverDocument>[];
      final uploadedCount = _requiredDocumentTypes
          .where((type) => _latestFor(type, documents) != null)
          .length;

      return FeatureScaffold(
        title: l.t('Vehicle Documents', 'Documents du véhicule'),
        children: [
          Text(
            l.t(
              '$uploadedCount of ${_requiredDocumentTypes.length} documents uploaded',
              '$uploadedCount sur ${_requiredDocumentTypes.length} documents téléversés',
            ),
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          if (_isUploading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(l.t('Uploading document to storage...', 'Téléversement du document en cours...')),
                  ],
                ),
              ),
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                for (var i = 0; i < _requiredDocumentTypes.length; i++) ...[
                  _DocumentChecklistTile(
                    typeLabel: _documentTypeLabel(_requiredDocumentTypes[i], l),
                    icon: _icon(_requiredDocumentTypes[i]),
                    document: _latestFor(_requiredDocumentTypes[i], documents),
                    onTap: _isUploading
                        ? null
                        : () => _showUploadDialog(
                            presetType: _requiredDocumentTypes[i],
                          ),
                  ),
                  if (i < _requiredDocumentTypes.length - 1) Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

  IconData _icon(String type) => switch (type) {
    'Insurance' => Icons.health_and_safety_outlined,
    'Road Licence' => Icons.description_outlined,
    'Fitness Certificate' => Icons.assignment_turned_in_outlined,
    'National ID' => Icons.badge_outlined,
    'Driver licence' => Icons.credit_card_outlined,
    _ => Icons.photo_library_outlined,
  };
}

/// One row of the document checklist: a required document type, a green check when a document
/// is on file, a red exclamation when it's still missing (or was rejected and needs
/// re-uploading) - the exact "green tick / red exclamation mark" checklist the driver asked for,
/// instead of the old list that only ever showed documents that already existed and silently
/// omitted anything the driver hadn't gotten to yet.
class _DocumentChecklistTile extends StatelessWidget {
  const _DocumentChecklistTile({
    required this.typeLabel,
    required this.icon,
    required this.document,
    required this.onTap,
  });

  final String typeLabel;
  final IconData icon;
  final DriverDocument? document;
  final VoidCallback? onTap;

  bool get _isSuccessfullyUploaded =>
      document != null && document!.status != DocumentStatus.rejected;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return ListTile(
    onTap: onTap,
    leading: IconWell(
      icon: icon,
      color: _isSuccessfullyUploaded
          ? AppColors.success
          : AppColors.textSecondaryFor(context),
      background: _isSuccessfullyUploaded
          ? AppColors.successSoftFor(context)
          : AppColors.backgroundFor(context),
    ),
    title: Text(
      typeLabel,
      style: TextStyle(
        color: AppColors.textPrimaryFor(context),
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Text(
      document == null
          ? l.t('Not uploaded yet - tap to upload', 'Pas encore téléversé - appuyez pour téléverser')
          : document!.status == DocumentStatus.rejected
          ? l.t('Rejected - tap to re-upload', 'Rejeté - appuyez pour téléverser à nouveau')
          : document!.expiresAt == null
          ? l.t('Uploaded', 'Téléversé')
          : l.t(
              'Valid until ${document!.expiresAt!.day}/${document!.expiresAt!.month}/${document!.expiresAt!.year}',
              "Valide jusqu'au ${document!.expiresAt!.day}/${document!.expiresAt!.month}/${document!.expiresAt!.year}",
            ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (document != null) ...[
          StatusBadge(
            label: _documentStatusLabel(document!.status, l),
            tone: switch (document!.status) {
              DocumentStatus.verified => BadgeTone.success,
              DocumentStatus.pending => BadgeTone.warning,
              DocumentStatus.rejected => BadgeTone.danger,
              _ => BadgeTone.info,
            },
            showDot: false,
          ),
          SizedBox(width: 8),
        ],
        Icon(
          _isSuccessfullyUploaded ? Icons.check_circle : Icons.error,
          color: _isSuccessfullyUploaded ? AppColors.success : AppColors.danger,
        ),
      ],
    ),
  );
  }
}
