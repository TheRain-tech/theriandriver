import '../../../core/localization/driver_copy.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
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
  final _attemptKey = const Uuid().v4();
  String? _paymentId;
  String? _paymentMessage;
  Timer? _pollTimer;
  bool _checking = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _paymentId != null) return;
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Enter the mobile money number to charge.',
              'Saisissez le numéro Mobile Money à débiter.',
            ),
          ),
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
        idempotencyKey: _attemptKey,
      );
      if (!mounted) return;

      if (session.paymentId.isEmpty) {
        throw StateError('Payment reference is missing.');
      }
      setState(() {
        _paymentId = session.paymentId;
        _paymentMessage = DriverCopy.current.t(
          'Approve the payment on your phone. Waiting for confirmation.',
          'Validez le paiement sur votre téléphone. Confirmation en attente.',
        );
      });
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkPayment(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverCopy.current.t(
              'Approve the payment prompt on your phone to complete the top-up.',
              'Validez la demande de paiement sur votre téléphone pour terminer la recharge.',
            ),
          ),
        ),
      );
      await _checkPayment();
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

  Future<void> _checkPayment() async {
    if (_checking || _paymentId == null || !mounted) return;
    _checking = true;
    try {
      final status = await _service.paymentStatus(_paymentId!);
      if (!mounted) return;
      if (status == 'SUCCESS') {
        _pollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              DriverCopy.current.t('Top-up confirmed.', 'Recharge confirmée.'),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else if (status == 'FAILED' || status == 'CANCELLED') {
        _pollTimer?.cancel();
        setState(
          () => _paymentMessage = DriverCopy.current.t(
            'Payment failed. No top-up was credited. Close this page before trying again.',
            'Paiement échoué. Aucune recharge créditée. Fermez cette page avant de réessayer.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _paymentMessage = DriverCopy.current.t(
            'Confirmation unavailable. Check again; do not submit another payment.',
            'Confirmation indisponible. Vérifiez à nouveau sans refaire le paiement.',
          ),
        );
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return FeatureScaffold(
      title: copy.t('Top Up Wallet', 'Recharger le portefeuille'),
      children: [
        if (_paymentId != null) ...[
          Text(
            _paymentMessage ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText(_paymentId!),
          TextButton(
            onPressed: _checkPayment,
            child: Text(copy.t('Check payment', 'Vérifier le paiement')),
          ),
          const SizedBox(height: 16),
        ],
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
                copy.t(
                  'Commission Wallet Top-Up',
                  'Recharge du portefeuille de commission',
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                copy.t(
                  'Top up your commission balance so you can go online and receive rides.',
                  'Rechargez votre solde de commission pour pouvoir passer en ligne et recevoir des courses.',
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
          decoration: InputDecoration(
            labelText: copy.t('Mobile Money Number', 'Numéro Mobile Money'),
            hintText: '6XX XXX XXX',
          ),
        ),
        SizedBox(height: 20),
        PrimaryButton(
          label:
              '${copy.t('Top Up', 'Recharger')} ${CurrencyFormatter.format(_amount)}',
          isLoading: _isSubmitting,
          onPressed: _isSubmitting || _paymentId != null ? null : _submit,
        ),
      ],
    );
  }
}
