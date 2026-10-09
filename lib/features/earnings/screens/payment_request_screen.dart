import '../../../core/localization/driver_copy.dart';
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
            : DriverCopy.current.t(
                'Could not load your available earnings.',
                "Impossible de charger vos revenus disponibles.",
              );
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
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Payment request submitted. TheRain admin will review it shortly.',
              "Demande de paiement envoyée. L'administration TheRain l'examinera sous peu.",
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final message = error is ApiException
          ? error.message
          : DriverCopy.current.t(
              'Could not submit your payment request. Please try again.',
              "Impossible d'envoyer votre demande de paiement. Veuillez réessayer.",
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return FeatureScaffold(
      title: copy.t('Request Payment', 'Demander un paiement'),
      children: [
        if (_isLoading)
          Padding(
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
                  style: TextStyle(color: AppColors.danger),
                ),
                SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _load,
                  child: Text(copy.t('Retry', 'Réessayer')),
                ),
              ],
            ),
          )
        else ...[
          AppCard(
            color: AppColors.primarySoftFor(context),
            borderColor: AppColors.primary,
            child: LabeledValue(
              label: copy.t('Available Earnings', 'Revenus disponibles'),
              value: CurrencyFormatter.format(_availableEarnings),
              icon: Icons.account_balance_wallet_rounded,
            ),
          ),
          SizedBox(height: 18),
          if (_hasOpenRequest)
            AppCard(
              color: AppColors.warningSoftFor(context),
              borderColor: AppColors.warning,
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy.t(
                        'You already have a payment request in progress. You '
                            'can submit a new one once it is resolved.',
                        'Vous avez déjà une demande de paiement en cours. '
                            'Vous pourrez en soumettre une nouvelle une fois '
                            'celle-ci résolue.',
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                      ),
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
                    decoration: InputDecoration(
                      labelText: copy.t(
                        'Requested Amount (XAF)',
                        'Montant demandé (XAF)',
                      ),
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (value) {
                      final amount = double.tryParse((value ?? '').trim());
                      if (amount == null || amount <= 0) {
                        return copy.t(
                          'Enter a valid amount',
                          'Saisissez un montant valide',
                        );
                      }
                      if (amount > _availableEarnings) {
                        return copy.t(
                          'Amount exceeds your available earnings',
                          'Le montant dépasse vos revenus disponibles',
                        );
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<PaymentRequestMethod>(
                    initialValue: _method,
                    decoration: InputDecoration(
                      labelText: copy.t('Payment Method', 'Mode de paiement'),
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
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _accountController,
                    decoration: InputDecoration(
                      labelText: copy.t(
                        'Account Details',
                        'Coordonnées du compte',
                      ),
                      hintText: copy.t(
                        'Phone number or bank account/IBAN',
                        'Numéro de téléphone ou compte bancaire/IBAN',
                      ),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? copy.t(
                            'Account details are required',
                            'Les coordonnées du compte sont requises',
                          )
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: copy.t('Notes (optional)', 'Notes (facultatif)'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  SizedBox(height: 24),
                  PrimaryButton(
                    label: copy.t('Submit Request', 'Envoyer la demande'),
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
}
