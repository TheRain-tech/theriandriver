import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class UploadBox extends StatelessWidget {
  const UploadBox({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isUploaded = false,
    this.isUploading = false,
    this.progress,
    this.errorText,
    this.icon = Icons.cloud_upload_outlined,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isUploaded;
  final bool isUploading;
  final double? progress;
  final String? errorText;
  final IconData icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: isUploading ? null : onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUploaded ? AppColors.success : AppColors.primary,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isUploaded
                ? Icons.check_circle_rounded
                : isUploading
                ? Icons.cloud_upload_rounded
                : icon,
            color: isUploaded ? AppColors.success : AppColors.primary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            isUploaded
                ? 'Uploaded'
                : isUploading
                ? 'Uploading...'
                : title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center),
          if (isUploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 5),
            Text('${((progress ?? 0) * 100).round()}%'),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              errorText!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
