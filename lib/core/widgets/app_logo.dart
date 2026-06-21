import 'package:flutter/material.dart';

import '../constants/asset_paths.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AssetPaths.logo,
      width: compact ? 52 : 132,
      height: compact ? 52 : 132,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'TheRain',
    );
  }
}
