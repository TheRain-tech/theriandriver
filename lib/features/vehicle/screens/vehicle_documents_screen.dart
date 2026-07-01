import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_document.dart';
import '../../../data/repositories/driver_vehicle_repository.dart';
import '../../../services/storage_upload_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

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

  void _showUploadDialog() {
    String selectedType = 'Insurance';
    String? pickedFilePath;
    DateTime? selectedExpiry;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload Document',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                      ),
                      items:
                          const [
                                'Insurance',
                                'Road Licence',
                                'Fitness Certificate',
                                'Vehicle Photos',
                                'National ID',
                                'Driver licence',
                              ]
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        pickedFilePath == null
                            ? 'Select Image'
                            : 'Image Selected',
                      ),
                      subtitle: Text(
                        pickedFilePath == null
                            ? 'Choose from gallery'
                            : pickedFilePath!.split('/').last,
                      ),
                      trailing: pickedFilePath != null
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        final file = await _uploadService.pickDocument();
                        if (file != null) {
                          setModalState(() => pickedFilePath = file.path);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        selectedExpiry == null
                            ? 'Expiry Date (Optional)'
                            : 'Expiry Date',
                      ),
                      subtitle: Text(
                        selectedExpiry == null
                            ? 'Not set'
                            : '${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}',
                      ),
                      trailing: const Icon(Icons.date_range_outlined),
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
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: pickedFilePath == null || _isUploading
                          ? null
                          : () async {
                              Navigator.pop(context); // Close sheet
                              setState(() {
                                _isUploading = true;
                              });
                              try {
                                await _repository.uploadDocument(
                                  type: selectedType,
                                  filePath: pickedFilePath!,
                                  expiresAt: selectedExpiry,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Document uploaded successfully.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  _retry();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'We could not upload this document.',
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
                      child: const Text('Upload'),
                    ),
                    const SizedBox(height: 20),
                  ],
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
      final documents = snapshot.data ?? const <DriverDocument>[];
      return FeatureScaffold(
        title: 'Vehicle Documents',
        children: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Uploading document to storage...'),
                  ],
                ),
              ),
            ),
          for (final document in documents) ...[
            AppCard(
              child: Row(
                children: [
                  IconWell(icon: _icon(document.type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.type,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          document.expiresAt == null
                              ? 'Front, back and side'
                              : 'Valid until ${document.expiresAt!.day}/${document.expiresAt!.month}/${document.expiresAt!.year}',
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: document.status.name,
                    tone: _tone(document.status),
                    showDot: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          AppOutlineButton(
            label: 'Upload Document',
            icon: Icons.upload_file_outlined,
            onPressed: _isUploading ? null : _showUploadDialog,
          ),
        ],
      );
    },
  );

  IconData _icon(String type) => switch (type) {
    'Insurance' => Icons.health_and_safety_outlined,
    'Road Licence' => Icons.description_outlined,
    'Fitness Certificate' => Icons.assignment_turned_in_outlined,
    _ => Icons.photo_library_outlined,
  };

  BadgeTone _tone(DocumentStatus status) => switch (status) {
    DocumentStatus.verified => BadgeTone.success,
    DocumentStatus.pending => BadgeTone.warning,
    DocumentStatus.rejected => BadgeTone.danger,
    _ => BadgeTone.info,
  };
}
