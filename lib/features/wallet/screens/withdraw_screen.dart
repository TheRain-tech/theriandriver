import '../../../core/localization/driver_copy.dart';
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
            DriverCopy.current.t(
              'Minimum withdrawal is ${CurrencyFormatter.format(minWithdrawal)}',
              'Le retrait minimum est de ${CurrencyFormatter.format(minWithdrawal)}',
            ),
          ),
        ),
      );
      return;
    }
    if (_amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t('Insufficient balance.', 'Solde insuffisant.'),
          ),
        ),
      );
      return;
    }
    if (_accountDetailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _paymentMethod == 'BANK_TRANSFER'
                ? DriverCopy.current.t(
                    'Enter your bank account number.',
                    'Saisissez votre numéro de compte bancaire.',
                  )
                : DriverCopy.current.t(
                    'Enter your mobile money number.',
                    'Saisissez votre numéro Mobile Money.',
                  ),
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
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Withdrawal request submitted.',
              'Demande de retrait envoyée.',
            ),
          ),
        ),
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
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final copy = DriverCopy.of(context);
      return FeatureScaffold(
        title: copy.t('Withdraw', 'Retirer'),
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
                  copy.t('Withdrawable Balance', 'Solde disponible au retrait'),
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(wallet.availableToWithdraw),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  copy.t(
                    'Minimum withdrawal: ${CurrencyFormatter.format(wallet.minimumWithdrawal)}',
                    'Retrait minimum : ${CurrencyFormatter.format(wallet.minimumWithdrawal)}',
                  ),
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          SizedBox(height: 22),
          Text(
            copy.t('Select Amount', 'Choisir le montant'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 10),
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
          SizedBox(height: 14),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: copy.t('Other Amount', 'Autre montant'),
              suffixText: 'XAF',
            ),
            onChanged: (value) => _amount = double.tryParse(value) ?? _amount,
          ),
          SizedBox(height: 20),
          Text(
            copy.t('Payment Method', 'Mode de paiement'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods
                .map(
                  (method) => ChoiceChip(
                    label: Text(
                      method.$1 == 'BANK_TRANSFER'
                          ? copy.t('Bank Transfer', 'Virement bancaire')
                          : method.$2,
                    ),
                    selected: _paymentMethod == method.$1,
                    onSelected: (_) =>
                        setState(() => _paymentMethod = method.$1),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 14),
          TextFormField(
            controller: _accountDetailsController,
            keyboardType: _paymentMethod == 'BANK_TRANSFER'
                ? TextInputType.text
                : TextInputType.phone,
            decoration: InputDecoration(
              labelText: _paymentMethod == 'BANK_TRANSFER'
                  ? copy.t('Bank Account Number', 'Numéro de compte bancaire')
                  : copy.t('Mobile Money Number', 'Numéro Mobile Money'),
              hintText: _paymentMethod == 'BANK_TRANSFER'
                  ? copy.t('Account number', 'Numéro de compte')
                  : '6XX XXX XXX',
            ),
          ),
          SizedBox(height: 20),
          PrimaryButton(
            label:
                '${copy.t('Withdraw', 'Retirer')} ${CurrencyFormatter.format(_amount)}',
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
            child: Text(copy.t('Withdrawal History', 'Historique des retraits')),
          ),
        ],
      );
    },
  );
}
