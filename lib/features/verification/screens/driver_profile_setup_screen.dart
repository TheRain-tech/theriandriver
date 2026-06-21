import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_verification_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/step_indicator.dart';

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
  final _plateNumber = TextEditingController();
  final _driverRepository = DriverRepository();
  String _vehicleType = 'Classic';
  String _color = 'Black';
  bool _isSaving = false;

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
    _plateNumber.text = draft.vehiclePlateNumber;
    _vehicleType = _vehicleTypeLabel(draft.vehicleType);
    _color = draft.vehicleColor.isEmpty ? 'Black' : draft.vehicleColor;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    try {
      final profile = await _driverRepository.getProfile(uid);
      if (!mounted || profile == null) return;
      setState(() {
        if (_fullName.text.isEmpty) _fullName.text = profile.fullName;
        if (_phone.text.isEmpty) _phone.text = profile.phone;
        if (_email.text.isEmpty) _email.text = profile.email;
        if (_plateNumber.text.isEmpty) {
          _plateNumber.text = profile.vehiclePlateNumber;
        }
        if (profile.vehicleType.isNotEmpty) {
          _vehicleType = _vehicleTypeLabel(profile.vehicleType);
        }
        if (profile.vehicleColor.isNotEmpty) {
          _color = profile.vehicleColor;
        }
      });
    } catch (_) {
      // The form remains usable with the authenticated account values.
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    final uid = AuthService.instance.currentUserId;
    if (uid == null) {
      _showError('Sign in before completing driver registration.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _driverRepository.saveProfileSetup(
        uid: uid,
        fullName: _fullName.text,
        phoneNumber: _phone.text,
        email: _email.text,
        vehicleType: _vehicleType,
        vehiclePlateNumber: _plateNumber.text,
        vehicleColor: _color,
      );
      RegistrationDraftService.instance.updateProfile(
        fullName: _fullName.text,
        phoneNumber: _phone.text,
        email: _email.text,
        vehicleType: _vehicleType,
        vehiclePlateNumber: _plateNumber.text,
        vehicleColor: _color,
      );
      DriverVerificationService.instance.start();
      if (!mounted) return;
      Navigator.pushNamed(context, RouteNames.nationalId);
    } catch (error) {
      if (!mounted) return;
      _showError(AuthService.instance.friendlyError(error));
      setState(() => _isSaving = false);
    }
  }

  String _vehicleTypeLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'vip' => 'VIP',
      'xl' => 'XL',
      'delivery' => 'Delivery',
      _ => 'Classic',
    };
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
    _plateNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const StepIndicator(current: 1),
                const SizedBox(height: 14),
                const Text(
                  'Step 1 of 5',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Driver Profile Setup',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Tell us about yourself and your vehicle.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _fullName,
                  validator: (value) => Validators.required(value, 'Full name'),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                  items: const ['Classic', 'VIP', 'XL', 'Delivery']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _vehicleType = value!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _plateNumber,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      Validators.required(value, 'Plate number'),
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Plate Number',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _color,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Color (Optional)',
                    prefixIcon: Icon(Icons.palette_outlined),
                  ),
                  items: const ['Black', 'White', 'Silver', 'Blue']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _color = value!),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _isSaving,
                  onPressed: _continue,
                ),
                const SizedBox(height: 12),
                AppOutlineButton(
                  label: 'Back',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16),
                    SizedBox(width: 7),
                    Text(
                      'Your information is safe and secure with us.',
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
