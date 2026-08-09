import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_wallet.dart';
import '../../../data/repositories/driver_wallet_repository.dart';
import '../../../router/route_names.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

const _paymentMethods = [
  ('MTN_MOMO', 'MTN Mobile Money'),
  ('ORANGE_MONEY', 'Orange Money'),
  ('BANK_TRANSFER', 'Bank Transfer'),
];

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _repository = DriverWalletRepository();
  final _accountDetailsController = TextEditingController();
  double _amount = 5000;
  String _paymentMethod = _paymentMethods.first.$1;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _accountDetailsController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal(double minWithdrawal, double available) async {
    if (_isSubmitting) return;
    if (_amount < minWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum withdrawal is ${CurrencyFormatter.format(minWithdrawal)}',
          ),
        ),
      );
      return;
    }
    if (_amount > available) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient balance.')));
      return;
    }
    if (_accountDetailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _paymentMethod == 'BANK_TRANSFER'
                ? 'Enter your bank account number.'
                : 'Enter your mobile money number.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repository.requestWithdrawal(
        _amount,
        paymentMethod: _paymentMethod,
        accountDetails: _accountDetailsController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted.')),
      );
      Navigator.pop(context);
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
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DriverWallet>(
    future: _repository.getWallet(),
    builder: (context, snapshot) {
      final wallet = snapshot.data;
      if (wallet == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FeatureScaffold(
        title: 'Withdraw',
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
                const Text(
                  'Withdrawable Balance',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(wallet.availableToWithdraw),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimum withdrawal: ${CurrencyFormatter.format(wallet.minimumWithdrawal)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Select Amount', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [2000.0, 5000.0, 10000.0]
                .map(
                  (value) => ChoiceChip(
                    label: Text(CurrencyFormatter.format(value)),
                    selected: _amount == value,
                    onSelected: (_) => setState(() => _amount = value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Other Amount',
              suffixText: 'XAF',
            ),
            onChanged: (value) => _amount = double.tryParse(value) ?? _amount,
          ),
          const SizedBox(height: 20),
          Text('Payment Method', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods
                .map(
                  (method) => ChoiceChip(
                    label: Text(method.$2),
                    selected: _paymentMethod == method.$1,
                    onSelected: (_) =>
                        setState(() => _paymentMethod = method.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _accountDetailsController,
            keyboardType: _paymentMethod == 'BANK_TRANSFER'
                ? TextInputType.text
                : TextInputType.phone,
            decoration: InputDecoration(
              labelText: _paymentMethod == 'BANK_TRANSFER'
                  ? 'Bank Account Number'
                  : 'Mobile Money Number',
              hintText: _paymentMethod == 'BANK_TRANSFER'
                  ? 'Account number'
                  : '6XX XXX XXX',
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Withdraw ${CurrencyFormatter.format(_amount)}',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting
                ? null
                : () => _submitWithdrawal(
                    wallet.minimumWithdrawal,
                    wallet.availableToWithdraw,
                  ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.withdrawalHistory),
            child: const Text('Withdrawal History'),
          ),
        ],
      );
    },
  );
}
