import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_profile.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/firebase_storage_service.dart';
import '../../../services/storage_upload_service.dart';
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
  final _uploadService = const StorageUploadService();
  final _storageService = FirebaseStorageService();
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

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

  Future<void> _changeAvatar(String uid) async {
    if (_isUploadingAvatar) return;
    try {
      final file = await _uploadService.pickDocument();
      if (file == null) return;
      setState(() => _isUploadingAvatar = true);
      final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final path = await _storageService.uploadFile(
        file: file,
        path: 'avatars/$uid/profile.$extension',
      );
      final url = await _storageService.getDownloadUrl(path);
      await DriverProfileService.instance.updateAvatarUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
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
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.primarySoft,
                backgroundImage:
                    profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        size: 72,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _isUploadingAvatar
                      ? null
                      : () => _changeAvatar(profile.id),
                  child: CircleAvatar(
                    backgroundColor: AppColors.navy,
                    child: _isUploadingAvatar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          enabled: !profile.lockedFields.contains('fullName'),
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          enabled: !profile.lockedFields.contains('phoneNumber'),
          decoration: const InputDecoration(labelText: 'Phone Number'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          enabled: !profile.lockedFields.contains('email'),
          decoration: const InputDecoration(labelText: 'Email'),
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
