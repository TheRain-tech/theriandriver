import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class ReferAndEarnScreen extends StatelessWidget {
  const ReferAndEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return FeatureScaffold(
      title: copy.t('Refer & Earn', 'Parrainer et gagner'),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.t('Refer a Driver', 'Parrainer un chauffeur'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                copy.t(
                  'Earn 3,000 XAF for each driver after they get approved.',
                  'Gagnez 3 000 XAF pour chaque chauffeur une fois approuvé.',
                ),
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 22),
              Text(
                copy.t('YOUR REFERRAL CODE', 'VOTRE CODE DE PARRAINAGE'),
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              SizedBox(height: 5),
              Text(
                'THERAIN2026',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        SectionHeader(title: copy.t('Share Your Code', 'Partagez votre code')),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ShareIcon(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              onTap: () => _comingSoon(context),
            ),
            _ShareIcon(
              icon: Icons.facebook_rounded,
              label: 'Facebook',
              onTap: () => _comingSoon(context),
            ),
            _ShareIcon(
              icon: Icons.sms_outlined,
              label: 'SMS',
              onTap: () => _comingSoon(context),
            ),
            _ShareIcon(
              icon: Icons.more_horiz_rounded,
              label: copy.t('More', 'Plus'),
              onTap: () => _comingSoon(context),
            ),
          ],
        ),
        SizedBox(height: 24),
        SectionHeader(title: copy.t('How it works', 'Comment ça marche')),
        SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              _Step(
                number: '1',
                text: copy.t(
                  'Share your referral code',
                  'Partagez votre code de parrainage',
                ),
              ),
              _Step(
                number: '2',
                text: copy.t(
                  'Your friend signs up as a driver',
                  "Votre ami s'inscrit en tant que chauffeur",
                ),
              ),
              _Step(
                number: '3',
                text: copy.t('They get approved', 'Il est approuvé'),
              ),
              _Step(
                number: '4',
                text: copy.t('You earn 3,000 XAF', 'Vous gagnez 3 000 XAF'),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        AppOutlineButton(
          label: copy.t('View Referral History', 'Voir l\'historique des parrainages'),
          onPressed: () => _comingSoon(context),
        ),
      ],
    );
  }

  static void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          DriverCopy.current.t(
            'Refer & Earn is coming soon.',
            'Parrainage et gains : bientôt disponible.',
          ),
        ),
      ),
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primarySoftFor(context),
          child: Icon(icon, color: AppColors.primary),
        ),
        SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.primarySoftFor(context),
          child: Text(
            number,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 12),
        Text(text),
      ],
    ),
  );
}
