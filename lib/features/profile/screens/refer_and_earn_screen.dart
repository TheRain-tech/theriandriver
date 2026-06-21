import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class ReferAndEarnScreen extends StatelessWidget {
  const ReferAndEarnScreen({super.key});

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Refer & Earn',
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Refer a Driver',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Earn 3,000 XAF for each driver after they get approved.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 22),
            Text(
              'YOUR REFERRAL CODE',
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
      const SizedBox(height: 20),
      const SectionHeader(title: 'Share Your Code'),
      const SizedBox(height: 10),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ShareIcon(icon: Icons.chat_rounded, label: 'WhatsApp'),
          _ShareIcon(icon: Icons.facebook_rounded, label: 'Facebook'),
          _ShareIcon(icon: Icons.sms_outlined, label: 'SMS'),
          _ShareIcon(icon: Icons.more_horiz_rounded, label: 'More'),
        ],
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'How it works'),
      const SizedBox(height: 8),
      const AppCard(
        child: Column(
          children: [
            _Step(number: '1', text: 'Share your referral code'),
            _Step(number: '2', text: 'Your friend signs up as a driver'),
            _Step(number: '3', text: 'They get approved'),
            _Step(number: '4', text: 'You earn 3,000 XAF'),
          ],
        ),
      ),
      const SizedBox(height: 20),
      AppOutlineButton(label: 'View Referral History', onPressed: () {}),
    ],
  );
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(icon, color: AppColors.primary),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
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
          backgroundColor: AppColors.primarySoft,
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(text),
      ],
    ),
  );
}
