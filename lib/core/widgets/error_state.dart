import 'package:flutter/material.dart';

import 'danger_button.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
          DangerButton(label: 'Try Again', onPressed: onRetry),
        ],
      ),
    ),
  );
}
