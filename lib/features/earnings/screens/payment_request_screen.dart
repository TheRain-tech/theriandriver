import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/payment_request.dart';
import '../../../data/repositories/driver_revenue_repository.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

/// TheRain-direct drivers ONLY (server-side enforced too — see
/// driverPayroll.service.js#assertDirectDriver). Available Earnings,
/// Requested Amount, Payment Method, Account Details, Notes, Submit.
class PaymentRequestScreen extends StatefulWidget {
  const PaymentRequestScreen({super.key});

  @override
  State<PaymentRequestScreen> createState() => _PaymentRequestScreenState();
}

class _PaymentRequestScreenState extends State<PaymentRequestScreen> {
  final _repository = DriverRevenueRepository();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentRequestMethod _method = PaymentRequestMethod.mtnMomo;
  bool _isSubmitting = false;
  bool _isLoading = true;
  double _availableEarnings = 0;
  bool _hasOpenRequest = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _repository.getWalletBalance(uid),
        _repository.listPaymentRequests(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _availableEarnings = results[0] as double;
        _hasOpenRequest = (results[1] as List<PaymentRequest>).any(
          (row) => row.isOpen,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is ApiException
            ? error.message
            : 'Could not load your available earnings.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    setState(() => _isSubmitting = true);
    try {
      await _repository.submitPaymentRequest(
        driverId: uid,
        amount: amount,
        method: _method,
        accountDetails: _accountController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment request submitted. TheRain admin will review it shortly.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final message = error is ApiException
          ? error.message
          : 'Could not submit your payment request. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Request Payment',
    children: [
      if (_isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_loadError != null)
        AppCard(
          child: Column(
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        )
      else ...[
        AppCard(
          color: AppColors.primarySoft,
          borderColor: AppColors.primary,
          child: LabeledValue(
            label: 'Available Earnings',
            value: CurrencyFormatter.format(_availableEarnings),
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        const SizedBox(height: 18),
        if (_hasOpenRequest)
          AppCard(
            color: AppColors.warningSoft,
            borderColor: AppColors.warning,
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You already have a payment request in progress. You '
                    'can submit a new one once it is resolved.',
                    style: TextStyle(color: AppColors.navy),
                  ),
                ),
              ],
            ),
          )
        else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Requested Amount (XAF)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim());
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    if (amount > _availableEarnings) {
                      return 'Amount exceeds your available earnings';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PaymentRequestMethod>(
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: PaymentRequestMethod.values
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _method = value ?? _method),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accountController,
                  decoration: const InputDecoration(
                    labelText: 'Account Details',
                    hintText: 'Phone number or bank account/IBAN',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Account details are required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Submit Request',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
      ],
    ],
  );
}
