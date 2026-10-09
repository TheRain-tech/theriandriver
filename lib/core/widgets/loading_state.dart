import 'package:flutter/material.dart';

import '../localization/driver_copy.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});
  // Null (the default) falls back to a localized "Loading..." - a const
  // default value can't call DriverCopy, so every caller that didn't pass an
  // explicit label used to get hardcoded English even in French.
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(label ?? DriverCopy.of(context).t('Loading...', 'Chargement...')),
      ],
    ),
  );
}
