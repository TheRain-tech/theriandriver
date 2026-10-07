import 'package:flutter/material.dart';

import '../services/driver_preferences_service.dart';
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
  // Guessed once from the device's own OS language, purely as a starting point so this screen
  // opens already reading in ONE language instead of a joined "Choose your language/Choisissez
  // votre langue" sentence - a driver whose phone is already in French sees French immediately;
  // anyone else sees English. Either can switch with a single tap below, and the title (unlike
  // the fixed option labels "English"/"Français", which are proper nouns and were never the
  // issue) follows that choice from then on.
  late String _selectedCode = WidgetsBinding
      .instance
      .platformDispatcher
      .locale
      .languageCode
      .toLowerCase() == 'fr'
      ? 'fr'
      : 'en';
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final locale = Locale(_selectedCode);
    // Two stores exist for historical reasons: LocaleService is the only one
    // tracking "has the first-launch picker been shown yet"; DriverPreferencesService
    // is what the app's MaterialApp/Settings screen actually read the live locale
    // from. Keeping both in sync here avoids a deeper merge of the two services.
    await LocaleService.instance.completeLanguageSelection(locale);
    await DriverPreferencesService.instance.setLocale(locale);
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
              Text(
                _selectedCode == 'fr'
                    ? 'Choisissez votre langue'
                    : 'Choose your language',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                    // The button's own label is the one piece of this screen that CAN follow a
                    // single language, since _selectedCode is already known the moment a driver
                    // taps an option - showing both joined by "/" here (unlike the title above,
                    // which genuinely cannot know their language yet) was an avoidable case of
                    // "two languages on screen at once".
                    : Text(_selectedCode == 'fr' ? 'Continuer' : 'Continue'),
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
