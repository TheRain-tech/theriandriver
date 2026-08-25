import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/top_up_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

const _topUpMethods = [
  ('MTN MOMO', 'MTN Mobile Money'),
  ('Orange Money', 'Orange Money'),
];

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _service = TopUpService();
  final _phoneController = TextEditingController();
  double _amount = 2000;
  String _method = _topUpMethods.first.$1;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the mobile money number to charge.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final session = await _service.createCommissionWalletTopUp(
        amount: _amount,
        paymentMethod: _method,
        phoneNumber: _phoneController.text.trim(),
      );
      if (!mounted) return;

      if (session.checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(session.checkoutUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Approve the payment prompt on your phone to complete the top-up.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst('Bad state: ', '')
                .replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Top Up Wallet',
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
              'Commission Wallet Top-Up',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Top up your commission balance so you can go online and receive rides.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      SizedBox(height: 22),
      Text('Select Amount', style: Theme.of(context).textTheme.titleLarge),
      SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [1000.0, 2000.0, 5000.0, 10000.0]
            .map(
              (value) => ChoiceChip(
                label: Text(CurrencyFormatter.format(value)),
                selected: _amount == value,
                onSelected: (_) => setState(() => _amount = value),
              ),
            )
            .toList(),
      ),
      SizedBox(height: 14),
      TextFormField(
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Other Amount',
          suffixText: 'XAF',
        ),
        onChanged: (value) => _amount = double.tryParse(value) ?? _amount,
      ),
      SizedBox(height: 20),
      Text('Payment Method', style: Theme.of(context).textTheme.titleLarge),
      SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _topUpMethods
            .map(
              (method) => ChoiceChip(
                label: Text(method.$2),
                selected: _method == method.$1,
                onSelected: (_) => setState(() => _method = method.$1),
              ),
            )
            .toList(),
      ),
      SizedBox(height: 14),
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Mobile Money Number',
          hintText: '6XX XXX XXX',
        ),
      ),
      SizedBox(height: 20),
      PrimaryButton(
        label: 'Top Up ${CurrencyFormatter.format(_amount)}',
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? null : _submit,
      ),
    ],
  );
}
