import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          child: Column(
            children: [
              const AppLogo(),
              const SizedBox(height: 8),
              const Text(
                AppConstants.tagline,
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.39,
                child: Image.asset(
                  AssetPaths.heroCar,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.directions_car_rounded,
                    size: 180,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const AppCard(
                child: Row(
                  children: [
                    IconWell(icon: Icons.shield_outlined, size: 54),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'A safer, smarter\n',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          children: [
                            TextSpan(
                              text: 'way to drive and earn.',
                              style: TextStyle(
                                color: AppColors.slate,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Get Started',
                icon: Icons.arrow_forward_rounded,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.signup),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, RouteNames.login),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
