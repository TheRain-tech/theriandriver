import 'package:flutter/material.dart';

import '../services/locale_service.dart';
import '../theme/app_colors.dart';

/// Shown once, on first launch, before the driver reaches any other screen —
/// mirrors the Fleet App's showLanguageSelectionModalIfNeeded/
/// _LanguageSelectionDialog pattern (lib/ui/language_selection_modal.dart in
/// THERAIN FLEET), adapted to this app's flutter_secure_storage-backed
/// LocaleService instead of shared_preferences.
Future<void> showLanguageSelectionModalIfNeeded(BuildContext context) async {
  if (LocaleService.instance.languageSelectionCompleted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => const _LanguageSelectionDialog(),
  );
}

class _LanguageSelectionDialog extends StatefulWidget {
  const _LanguageSelectionDialog();

  @override
  State<_LanguageSelectionDialog> createState() =>
      _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<_LanguageSelectionDialog> {
  String _selectedCode = 'en';
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    await LocaleService.instance.completeLanguageSelection(
      Locale(_selectedCode),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your language\nChoisissez votre langue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _LanguageOption(
                flag: '🇬🇧',
                label: 'English',
                selected: _selectedCode == 'en',
                onTap: () => setState(() => _selectedCode = 'en'),
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                flag: '🇫🇷',
                label: 'Français',
                selected: _selectedCode == 'fr',
                onTap: () => setState(() => _selectedCode = 'fr'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _saving ? null : _confirm,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue / Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primarySoft : null,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
