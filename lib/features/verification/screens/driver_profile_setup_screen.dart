import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_verification_service.dart';
import '../../../services/phone_auth_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';

class DriverProfileSetupScreen extends StatefulWidget {
  const DriverProfileSetupScreen({super.key});

  @override
  State<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState extends State<DriverProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _plateNumber = TextEditingController();
  final _seats = TextEditingController(text: '4');
  final _cityRegion = TextEditingController();
  final _payoutName = TextEditingController();
  final _payoutNumber = TextEditingController();
  final _driverRepository = DriverRepository();
  String _vehicleType = 'Classic';
  String _color = 'Black';
  String _payoutProvider = 'MTN MoMo';
  bool _isSaving = false;
  bool _isEditingAccount = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    final draft = RegistrationDraftService.instance.value;
    _fullName.text = draft.fullName.isNotEmpty
        ? draft.fullName
        : user?.displayName ?? '';
    _phone.text = draft.phoneNumber.isNotEmpty
        ? draft.phoneNumber
        : user?.phoneNumber ?? '';
    _email.text = draft.email.isNotEmpty ? draft.email : user?.email ?? '';
    _vehicleModel.text = draft.vehicleModel;
    _plateNumber.text = draft.vehiclePlateNumber;
    _seats.text = draft.numberOfSeats.toString();
    _cityRegion.text = draft.cityRegion;
    _payoutName.text = draft.payoutAccountName.isNotEmpty
        ? draft.payoutAccountName
        : draft.fullName;
    _payoutNumber.text = draft.payoutAccountNumber.isNotEmpty
        ? draft.payoutAccountNumber
        : draft.phoneNumber;
    _vehicleType = _vehicleTypeLabel(draft.vehicleType);
    _color = draft.vehicleColor.isEmpty ? 'Black' : draft.vehicleColor;
    _payoutProvider = _payoutProviderLabel(draft.payoutProvider);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    try {
      final profile = await _driverRepository.getProfile(uid);
      if (!mounted || profile == null) return;
      final payout = await _driverRepository.getDefaultPayoutAccount(uid);
      if (!mounted) return;
      setState(() {
        if (_fullName.text.isEmpty) _fullName.text = profile.fullName;
        if (_phone.text.isEmpty) _phone.text = profile.phone;
        if (_email.text.isEmpty) _email.text = profile.email;
        if (_plateNumber.text.isEmpty) {
          _plateNumber.text = profile.vehiclePlateNumber;
        }
        if (_vehicleModel.text.isEmpty) {
          _vehicleModel.text = profile.vehicleModel;
        }
        if (_cityRegion.text.isEmpty) {
          _cityRegion.text = profile.cityRegion;
        }
        if (profile.vehicleType.isNotEmpty) {
          _vehicleType = _vehicleTypeLabel(profile.vehicleType);
        }
        if (profile.vehicleColor.isNotEmpty) {
          _color = profile.vehicleColor;
        }
        if (payout != null) {
          if (_payoutName.text.isEmpty) {
            _payoutName.text = payout['accountName']?.toString() ?? '';
          }
          if (_payoutNumber.text.isEmpty) {
            _payoutNumber.text = payout['accountNumber']?.toString() ?? '';
          }
          final provider = payout['provider']?.toString();
          if (provider != null) {
            _payoutProvider = _payoutProviderLabel(provider);
          }
        }
      });
    } catch (_) {
      // The form remains usable with the authenticated account values.
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    final seats = int.tryParse(_seats.text.trim()) ?? 0;
    if (seats < 1 || seats > 12) {
      _showError(
        DriverCopy.current.t(
          'Enter the number of passenger seats.',
          'Saisissez le nombre de places passagers.',
        ),
      );
      return;
    }
    final payoutNumber = _normalizedPayoutNumber();
    if (payoutNumber == null) {
      _showError(
        DriverCopy.current.t(
          'Enter a valid Cameroon mobile money number.',
          'Saisissez un numéro Mobile Money camerounais valide.',
        ),
      );
      return;
    }
    final uid = AuthService.instance.currentUserId;

    setState(() => _isSaving = true);
    try {
      if (uid != null) {
        // Guard: ensure both Firestore documents exist before the profile-setup
        // UPDATE. Without this, a user who reaches this screen without a prior
        // seedDriverProfile call would trigger a Firestore CREATE with the wrong
        // fields (verificationStatus: 'inProgress', missing uid/role), which
        // fails the CREATE security rule.
        await _driverRepository.seedDriverProfile(
          uid: uid,
          fullName: _fullName.text.trim().isNotEmpty
              ? _fullName.text
              : 'Driver',
          phoneNumber: _phone.text,
          email: _email.text,
          cityRegion: _cityRegion.text,
        );

        await _driverRepository.saveProfileSetup(
          uid: uid,
          fullName: _fullName.text,
          phoneNumber: _phone.text,
          email: _email.text,
          vehicleType: _vehicleType,
          vehicleModel: _vehicleModel.text,
          vehiclePlateNumber: _plateNumber.text,
          vehicleColor: _color,
          numberOfSeats: seats,
          cityRegion: _cityRegion.text,
          payoutProvider: _payoutProvider,
          payoutAccountName: _payoutName.text,
          payoutAccountNumber: payoutNumber,
        );
        DriverVerificationService.instance.start();
      }
      RegistrationDraftService.instance.updateProfile(
        fullName: _fullName.text,
        phoneNumber: _phone.text,
        email: _email.text,
        vehicleType: _vehicleType,
        vehicleModel: _vehicleModel.text,
        vehiclePlateNumber: _plateNumber.text,
        vehicleColor: _color,
        numberOfSeats: seats,
        cityRegion: _cityRegion.text,
        payoutProvider: _payoutProvider,
        payoutAccountName: _payoutName.text,
        payoutAccountNumber: payoutNumber,
        acceptedTerms:
            RegistrationDraftService.instance.value.acceptedTerms ||
            uid != null,
      );
      if (!mounted) return;

      // Verify phone via WhatsApp OTP before proceeding to KYC.
      // Entirely optional — driver proceeds whether or not OTP is verified.
      if (uid != null) {
        try {
          final profile = await _driverRepository.getProfile(uid);
          final alreadyVerified = profile?.phoneVerified ?? false;
          if (!alreadyVerified && mounted) {
            await _showOtpVerification(_phone.text);
          }
        } catch (_) {
          // OTP check is best-effort; never block the onboarding flow.
        }
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        _returnToReview ? RouteNames.review : RouteNames.region,
      );
    } catch (error) {
      if (!mounted) return;
      _showError(AuthService.instance.friendlyError(error));
      setState(() => _isSaving = false);
    }
  }

  Future<void> _showOtpVerification(String phone) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _OtpVerificationSheet(phone: phone),
    );
  }

  String _vehicleTypeLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'vip' => 'VIP',
      'xl' => 'XL',
      'delivery' => 'Delivery',
      _ => 'Classic',
    };
  }

  String _payoutProviderLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'orange_money' || 'orange money' => 'Orange Money',
      'bank' => 'Bank',
      _ => 'MTN MoMo',
    };
  }

  // The canonical values above (and the dropdown item values below) are
  // submitted to the backend as-is and must stay in English - only the
  // on-screen label is translated.
  String _vehicleTypeDisplay(String value, DriverCopy l) => switch (value) {
    'VIP' => l.t('VIP', 'VIP'),
    'XL' => l.t('XL', 'XL'),
    'Delivery' => l.t('Delivery', 'Livraison'),
    _ => l.t('Classic', 'Classique'),
  };

  String _colorDisplay(String value, DriverCopy l) => switch (value) {
    'White' => l.t('White', 'Blanc'),
    'Silver' => l.t('Silver', 'Argent'),
    'Blue' => l.t('Blue', 'Bleu'),
    _ => l.t('Black', 'Noir'),
  };

  String _payoutProviderDisplay(String value, DriverCopy l) => switch (value) {
    'Orange Money' => l.t('Orange Money', 'Orange Money'),
    'Bank' => l.t('Bank', 'Banque'),
    _ => l.t('MTN MoMo', 'MTN MoMo'),
  };

  bool get _returnToReview {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['returnToReview'] == true;
  }

  bool get _accountNeedsCompletion =>
      _isEditingAccount ||
      _fullName.text.trim().isEmpty ||
      _phone.text.trim().isEmpty ||
      _email.text.trim().isEmpty;

  String? _normalizedPayoutNumber() {
    final provider = _payoutProvider.trim().toLowerCase();
    if (provider == 'mtn momo' || provider == 'orange money') {
      return CameroonPhoneNumber.normalize(_payoutNumber.text);
    }
    final value = _payoutNumber.text.trim();
    return value.isEmpty ? null : value;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _vehicleModel.dispose();
    _plateNumber.dispose();
    _seats.dispose();
    _cityRegion.dispose();
    _payoutName.dispose();
    _payoutNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
      appBar: const DriverAppBar(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.t('VEHICLE AND PAYMENT', 'VÉHICULE ET PAIEMENT'),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  l.t(
                    'Tell us what you will drive',
                    'Dites-nous ce que vous allez conduire',
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 5),
                Text(
                  l.t(
                    'We already have your account details. Add the vehicle and receiving account that belong to you.',
                    'Nous avons déjà les détails de votre compte. Ajoutez le véhicule et le compte de réception qui vous appartiennent.',
                  ),
                ),
                SizedBox(height: 18),
                AppCard(
                  color: AppColors.primarySoftFor(context),
                  borderColor: AppColors.primarySoftFor(context),
                  child: Row(
                    children: [
                      IconWell(icon: Icons.person_outline_rounded),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fullName.text.isEmpty
                                  ? l.t('Driver account', 'Compte chauffeur')
                                  : _fullName.text,
                              style: TextStyle(
                                color: AppColors.textPrimaryFor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(_phone.text),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isEditingAccount = true),
                        child: Text(l.t('Edit', 'Modifier')),
                      ),
                    ],
                  ),
                ),
                if (_accountNeedsCompletion) ...[
                  SizedBox(height: 14),
                  TextFormField(
                    controller: _fullName,
                    validator: (value) => Validators.required(
                      value,
                      l.t('Full name', 'Nom complet'),
                    ),
                    decoration: InputDecoration(
                      labelText: l.t('Full Name', 'Nom complet'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                    decoration: InputDecoration(
                      labelText: l.t('Phone Number', 'Numéro de téléphone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    decoration: InputDecoration(
                      labelText: l.t('Email Address', 'Adresse e-mail'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                ],
                SizedBox(height: 22),
                Text(
                  l.t('Vehicle', 'Véhicule'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleType,
                  decoration: InputDecoration(
                    labelText: l.t('Ride Class', 'Classe de course'),
                    prefixIcon: const Icon(Icons.directions_car_outlined),
                  ),
                  items: const ['Classic', 'VIP', 'XL', 'Delivery']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_vehicleTypeDisplay(value, l)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _vehicleType = value!),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _vehicleModel,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(
                    value,
                    l.t('Vehicle model', 'Modèle du véhicule'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t('Vehicle Model', 'Modèle du véhicule'),
                    hintText: l.t('e.g. Toyota Corolla', 'ex. Toyota Corolla'),
                    prefixIcon: const Icon(Icons.car_repair_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _plateNumber,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) => Validators.required(
                    value,
                    l.t('Plate number', 'Numéro de plaque'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t(
                      'Vehicle Plate Number',
                      'Numéro de plaque du véhicule',
                    ),
                    prefixIcon: const Icon(Icons.pin_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _seats,
                  keyboardType: TextInputType.number,
                  validator: (value) => Validators.required(
                    value,
                    l.t('Number of seats', 'Nombre de places'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t('Passenger Seats', 'Places passagers'),
                    prefixIcon: const Icon(Icons.event_seat_outlined),
                  ),
                ),
                SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _color,
                  decoration: InputDecoration(
                    labelText: l.t(
                      'Vehicle Color (Optional)',
                      'Couleur du véhicule (facultatif)',
                    ),
                    prefixIcon: const Icon(Icons.palette_outlined),
                  ),
                  items: const ['Black', 'White', 'Silver', 'Blue']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_colorDisplay(value, l)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _color = value!),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _cityRegion,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(
                    value,
                    l.t('City or region', 'Ville ou région'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t('Operating City', 'Ville d\'exploitation'),
                    hintText: l.t('e.g. Bamenda', 'ex. Bamenda'),
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  l.t('Receiving Account', 'Compte de réception'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _payoutProvider,
                  decoration: InputDecoration(
                    labelText: l.t('Payout Method', 'Méthode de paiement'),
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  items: const ['MTN MoMo', 'Orange Money', 'Bank']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_payoutProviderDisplay(value, l)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _payoutProvider = value!),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _payoutName,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(
                    value,
                    l.t('Account name', 'Nom du compte'),
                  ),
                  decoration: InputDecoration(
                    labelText: l.t('Account Name', 'Nom du compte'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _payoutNumber,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final required = Validators.required(
                      value,
                      l.t('Account number', 'Numéro de compte'),
                    );
                    if (required != null) return required;
                    final provider = _payoutProvider.trim().toLowerCase();
                    if (provider == 'mtn momo' || provider == 'orange money') {
                      return CameroonPhoneNumber.validateMobileMoney(value);
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: l.t(
                      'Account Number / Phone',
                      'Numéro de compte / Téléphone',
                    ),
                    prefixIcon: const Icon(Icons.phone_android_outlined),
                  ),
                ),
                SizedBox(height: 22),
                PrimaryButton(
                  label: l.t('Save and continue', 'Enregistrer et continuer'),
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _isSaving,
                  onPressed: _continue,
                ),
                SizedBox(height: 12),
                AppOutlineButton(
                  label: l.t('Back', 'Retour'),
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.maybePop(context),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16),
                    SizedBox(width: 7),
                    Text(
                      l.t(
                        'Your information is safe and secure with us.',
                        'Vos informations sont en sécurité avec nous.',
                      ),
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpVerificationSheet extends StatefulWidget {
  const _OtpVerificationSheet({required this.phone});
  final String phone;

  @override
  State<_OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<_OtpVerificationSheet> {
  final _codeController = TextEditingController();
  final _phoneAuthService = PhoneAuthService();
  final _driverRepository = DriverRepository();
  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  String? _error;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await _phoneAuthService.requestOtp(
        phoneNumber: widget.phone,
        forceResendingToken: _resendToken,
      );
      if (!mounted) return;
      _verificationId = result.verificationId;
      _resendToken = result.resendToken;
      final autoCredential = result.autoCredential;
      if (autoCredential != null) {
        await _completeVerification(autoCredential);
        return;
      }
      setState(() => _codeSent = true);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyPhoneError(error));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = DriverCopy.current.t(
            'Could not send the verification code. Check your number and try again.',
            'Impossible d\'envoyer le code de vérification. Vérifiez votre numéro et réessayez.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(
        () => _error = DriverCopy.current.t(
          'Enter the 6-digit code sent to your phone.',
          'Saisissez le code à 6 chiffres envoyé sur votre téléphone.',
        ),
      );
      return;
    }
    if (verificationId == null) {
      setState(
        () => _error = DriverCopy.current.t(
          'Request a new code and try again.',
          'Demandez un nouveau code et réessayez.',
        ),
      );
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _phoneAuthService.linkPhoneCredential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _markVerifiedAndClose();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyPhoneError(error));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = DriverCopy.current.t(
            'Verification failed. Please try again.',
            'Échec de la vérification. Veuillez réessayer.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _completeVerification(PhoneAuthCredential credential) async {
    // Android's SMS auto-retrieval already confirmed the code - nothing left to type.
    try {
      await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'credential-already-in-use' &&
          error.code != 'provider-already-linked') {
        if (mounted) setState(() => _error = _friendlyPhoneError(error));
        return;
      }
    }
    await _markVerifiedAndClose();
  }

  Future<void> _markVerifiedAndClose() async {
    final uid = AuthService.instance.currentUserId;
    if (uid != null) {
      try {
        await _driverRepository.markPhoneVerified(uid);
      } catch (_) {
        // Best-effort - the phone was genuinely verified even if this write fails; the
        // profile screen will simply ask again next time it loads.
      }
    }
    if (mounted) Navigator.pop(context);
  }

  String _friendlyPhoneError(FirebaseAuthException error) {
    final l = DriverCopy.current;
    return switch (error.code) {
      'invalid-verification-code' => l.t(
        'Incorrect code. Try again.',
        'Code incorrect. Réessayez.',
      ),
      'invalid-verification-id' || 'session-expired' => l.t(
        'That code expired. Request a new one.',
        'Ce code a expiré. Demandez-en un nouveau.',
      ),
      'invalid-phone-number' => l.t(
        'Enter a valid phone number.',
        'Saisissez un numéro de téléphone valide.',
      ),
      'too-many-requests' || 'quota-exceeded' => l.t(
        'Too many attempts. Try again later.',
        'Trop de tentatives. Réessayez plus tard.',
      ),
      'network-request-failed' => l.t(
        'Check your internet connection and try again.',
        'Vérifiez votre connexion internet et réessayez.',
      ),
      'credential-already-in-use' || 'provider-already-linked' => l.t(
        'This number is already verified.',
        'Ce numéro est déjà vérifié.',
      ),
      _ =>
        error.message ??
            l.t(
              'Verification failed. Please try again.',
              'Échec de la vérification. Veuillez réessayer.',
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            l.t('Verify your phone number', 'Vérifiez votre numéro de téléphone'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            l.t(
              'We\'ll send a verification code by SMS to ${widget.phone}.',
              'Nous enverrons un code de vérification par SMS au ${widget.phone}.',
            ),
            style: TextStyle(color: Colors.black54),
          ),
          if (_error != null) ...[
            SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red)),
          ],
          SizedBox(height: 20),
          if (_codeSent) ...[
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.t(
                  'Enter verification code',
                  'Saisissez le code de vérification',
                ),
                counterText: '',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifying ? null : _verifyOtp,
              child: _verifying
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.t('Verify', 'Vérifier')),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _sending ? null : _sendOtp,
              child: Text(l.t('Resend code', 'Renvoyer le code')),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _sending ? null : _sendOtp,
              child: _sending
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      l.t('Send verification code', 'Envoyer le code de vérification'),
                    ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.t('Skip for now', 'Ignorer pour le moment')),
          ),
        ],
      ),
    );
  }
}
