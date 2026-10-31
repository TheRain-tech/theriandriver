import '../../../core/localization/driver_copy.dart';
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
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';

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
  bool _isPickingEvidence = false;
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
    if (_isPickingEvidence || _isSubmitting) return;
    setState(() => _isPickingEvidence = true);
    try {
      final image = await _upload.pickDocument();
      if (image != null && mounted) {
        setState(() => _localImagePaths.add(image.path));
      }
    } finally {
      if (mounted) setState(() => _isPickingEvidence = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l = DriverCopy.of(context);
    if (_reason == FleetReportReason.other &&
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'Please describe the issue when reason is "Other".',
              'Veuillez décrire le problème lorsque le motif est « Autre ».',
            ),
          ),
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
        SnackBar(
          content: Text(
            l.t(
              'Your report has been submitted to TheRain Compliance. '
                  'You can track its status below.',
              'Votre signalement a été transmis à la conformité TheRain. Vous pouvez suivre son statut ci-dessous.',
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _descriptionController.clear();
      setState(() {
        _reason = FleetReportReason.salaryCommissionDispute;
        _localImagePaths.clear();
        _isSubmitting = false;
        _historyFuture = _loadHistory();
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : l.t(
              'We could not submit your report. Please try again.',
              "Impossible d'envoyer votre signalement. Veuillez réessayer.",
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: l.t('Report Fleet', 'Signaler la flotte')),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoCard(
                      title: l.t('Report a Fleet Issue', 'Signaler un problème de flotte'),
                      body: l.t(
                        "Help us keep our fleet safe, compliant and reliable. Your report will be reviewed by TheRain's Compliance & Safety Team.",
                        "Aidez-nous à garantir la sécurité, la conformité et la fiabilité de notre flotte. Votre signalement sera examiné par l'équipe Conformité et Sécurité de TheRain.",
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.t('Reason', 'Motif'),
                            style: TextStyle(
                              color: AppColors.textSecondaryFor(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<FleetReportReason>(
                            initialValue: _reason,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: FleetReportReason.values
                                .map(
                                  (reason) => DropdownMenuItem(
                                    value: reason,
                                    child: Text(reason.localizedLabel(l)),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) =>
                                    setState(() => _reason = value ?? _reason),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _reason == FleetReportReason.other
                                ? l.t('Description (required)', 'Description (requise)')
                                : l.t('Description (optional)', 'Description (facultative)'),
                            style: TextStyle(
                              color: AppColors.textSecondaryFor(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionController,
                            enabled: !_isSubmitting,
                            minLines: 5,
                            maxLines: 8,
                            maxLength: 1000,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: l.t(
                                'Describe the issue in detail...',
                                "Décrivez le problème en détail...",
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AttachmentSection(
                      paths: _localImagePaths,
                      isSubmitting: _isSubmitting,
                      isPicking: _isPickingEvidence,
                      uploadProgress: _uploadProgress,
                      onAdd: _pickEvidence,
                      onRemove: (path) =>
                          setState(() => _localImagePaths.remove(path)),
                    ),
                    const SizedBox(height: 22),
                    DangerButton(
                      label: l.t('Submit Report', 'Envoyer le signalement'),
                      icon: Icons.description_rounded,
                      isLoading: _isSubmitting,
                      borderRadius: 30,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l.t('Your Reports', 'Vos signalements'),
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<FleetReport>>(
                      future: _historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final reports = snapshot.data ?? const [];
                        if (reports.isEmpty) {
                          return _EmptyReportsState(
                            message: l.t(
                              'You have not filed any fleet reports.',
                              "Vous n'avez déposé aucun signalement de flotte.",
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              report.localizedReasonLabel(l),
                                              style: TextStyle(
                                                color: AppColors
                                                    .textPrimaryFor(context),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l.t(
                                                'Filed ${DateFormatter.short(report.createdAt)} • ID ${report.id}',
                                                'Déposé le ${DateFormatter.short(report.createdAt)} • ID ${report.id}',
                                              ),
                                              style: TextStyle(
                                                color: AppColors
                                                    .textSecondaryFor(context),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(
                                        label: _statusLabel(report.status, l),
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
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 4),
    );
  }

  String _statusLabel(String status, DriverCopy l) => switch (status) {
    'PENDING' => l.t('Pending', 'En attente'),
    'UNDER_REVIEW' => l.t('Under Review', 'En cours d\'examen'),
    'RESOLVED' => l.t('Resolved', 'Résolu'),
    'CLOSED' => l.t('Closed', 'Clôturé'),
    _ => status,
  };

  BadgeTone _statusTone(String status) => switch (status) {
    'RESOLVED' => BadgeTone.success,
    'UNDER_REVIEW' => BadgeTone.info,
    'CLOSED' => BadgeTone.neutral,
    _ => BadgeTone.warning,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimaryFor(context),
            ),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.primarySoftFor(context),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.shield_outlined,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.paths,
    required this.isSubmitting,
    required this.isPicking,
    required this.uploadProgress,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final bool isSubmitting;
  final bool isPicking;
  final double uploadProgress;
  final VoidCallback onAdd;
  final void Function(String path) onRemove;

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoftFor(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!isSubmitting)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondaryFor(context),
                        ),
                        onPressed: () => onRemove(path),
                      ),
                  ],
                ),
              ),
            ),
          DottedUploadTarget(
            isBusy: isPicking || (isSubmitting && paths.isNotEmpty),
            progress: isSubmitting ? uploadProgress : null,
            icon: Icons.attach_file_rounded,
            title: l.t(
              'Add Photo/Document (Optional)',
              'Ajouter une photo/un document (facultatif)',
            ),
            subtitle: isPicking
                ? l.t('Opening picker…', 'Ouverture du sélecteur…')
                : l.t(
                    'Tap to add or take a photo',
                    'Appuyez pour ajouter ou prendre une photo',
                  ),
            onTap: isSubmitting ? null : onAdd,
          ),
        ],
      ),
    );
  }
}

/// A dashed-border tap target, matching the reference design's attachment
/// box - UploadBox (feature_templates' solid-border sibling) is used
/// elsewhere for a single required document and isn't reused here since this
/// one allows multiple optional attachments with per-file remove controls
/// above it, not a single uploaded/not-uploaded state.
class DottedUploadTarget extends StatelessWidget {
  const DottedUploadTarget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isBusy = false,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isBusy;
  final double? progress;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: isBusy ? null : onTap,
    borderRadius: BorderRadius.circular(14),
    child: CustomPaint(
      painter: _DashedBorderPainter(color: AppColors.primary),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimaryFor(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 13,
              ),
            ),
            if (isBusy && progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(
          Icons.history_edu_outlined,
          size: 40,
          color: AppColors.textSecondaryFor(context),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondaryFor(context)),
        ),
      ],
    ),
  );
}
