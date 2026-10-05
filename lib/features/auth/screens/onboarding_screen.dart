import 'package:flutter/material.dart';

import '../../../core/constants/asset_paths.dart';
import '../../../core/localization/driver_copy.dart';
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
              SizedBox(height: 8),
              Text(
                DriverCopy.of(context).t(
                  'Ride • Delivery • Comfort',
                  'Course • Livraison • Confort',
                ),
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 18),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.39,
                child: Image.asset(
                  AssetPaths.heroCar,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.directions_car_rounded,
                    size: 180,
                    color: AppColors.primary,
                  ),
                ),
              ),
              AppCard(
                child: Row(
                  children: [
                    IconWell(icon: Icons.shield_outlined, size: 54),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: DriverCopy.of(
                            context,
                          ).t('A safer, smarter\n', 'Une façon plus sûre\n'),
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          children: [
                            TextSpan(
                              text: DriverCopy.of(context).t(
                                'way to drive and earn.',
                                'et plus intelligente de conduire et de gagner.',
                              ),
                              style: TextStyle(
                                color: AppColors.textSecondaryFor(context),
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
              SizedBox(height: 22),
              PrimaryButton(
                label: DriverCopy.of(context).t('Get Started', 'Commencer'),
                icon: Icons.arrow_forward_rounded,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.signup),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, RouteNames.login),
                child: Text(
                  DriverCopy.of(
                    context,
                  ).t('Already have an account? Log in', 'Déjà un compte ? Se connecter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
