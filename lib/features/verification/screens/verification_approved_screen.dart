import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class VerificationApprovedScreen extends StatelessWidget {
  const VerificationApprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppLogo(compact: true)),
              SizedBox(height: 30),
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.successSoftFor(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 108,
                  color: AppColors.success,
                ),
              ),
              SizedBox(height: 26),
              Text.rich(
                const TextSpan(
                  text: "You're ",
                  children: [
                    TextSpan(
                      text: 'Approved!',
                      style: TextStyle(color: AppColors.success),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: 10),
              Text(
                'Your driver account is now verified and ready to receive ride requests.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.45),
              ),
              SizedBox(height: 24),
              AppCard(
                child: Row(
                  children: [
                    IconWell(
                      icon: Icons.shield_outlined,
                      color: AppColors.success,
                      background: AppColors.successSoftFor(context),
                      size: 58,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Status'),
                          SizedBox(height: 4),
                          Text(
                            'Approved',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(label: 'Active'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              AppCard(
                color: AppColors.successSoftFor(context),
                borderColor: Color(0xFFBCEACB),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up_rounded, color: AppColors.success),
                    SizedBox(width: 12),
                    Text(
                      'You can now go online and start earning!',
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22),
              PrimaryButton(
                label: 'Continue to Dashboard',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.dashboard,
                  (route) => false,
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.profile),
                child: Text('View Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
