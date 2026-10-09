import 'package:flutter/material.dart';

import '../localization/driver_copy.dart';
import 'danger_button.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.retryLabel});
  final String message;
  final VoidCallback onRetry;
  // Every generic error screen using ErrorState previously showed an
  // English "Try Again" button with no way to override it, even when the
  // rest of the screen was correctly in French.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 52),
          SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: 20),
          DangerButton(
            label: retryLabel ?? DriverCopy.of(context).t('Try Again', 'Réessayer'),
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}
