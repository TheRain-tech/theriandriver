import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_profile.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = DriverProfileService.instance.profile.value;
    _name = TextEditingController(text: profile.fullName);
    _phone = TextEditingController(text: profile.phone);
    _email = TextEditingController(text: profile.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await DriverProfileService.instance.updateContact(
        fullName: name,
        phone: phone,
        email: email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not update your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DriverProfile>(
    valueListenable: DriverProfileService.instance.profile,
    builder: (context, profile, _) => FeatureScaffold(
      title: 'Edit Profile',
      children: [
        const Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  Icons.person_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          decoration: const InputDecoration(labelText: 'Phone Number'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: 'Classic',
          decoration: const InputDecoration(labelText: 'Vehicle Type'),
          items: const ['Classic', 'VIP', 'XL', 'Delivery']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Save Changes',
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _saveChanges,
        ),
      ],
    ),
  );
}
