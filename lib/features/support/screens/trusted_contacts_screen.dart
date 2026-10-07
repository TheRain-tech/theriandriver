import '../../../core/localization/driver_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/trusted_contact.dart';
import '../../../services/trusted_contacts_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/feature_templates.dart';
import '../widgets/trusted_contact_card.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  List<TrustedContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await TrustedContactsService.instance.load();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _addContact(TrustedContact contact) async {
    final updated = [..._contacts, contact];
    setState(() => _contacts = updated);
    await TrustedContactsService.instance.save(updated);
  }

  Future<void> _removeContact(TrustedContact contact) async {
    final updated = _contacts.where((c) => c.id != contact.id).toList();
    setState(() => _contacts = updated);
    await TrustedContactsService.instance.save(updated);
  }

  Future<void> _confirmCall(TrustedContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DriverCopy.current.t(
            'Call ${contact.name}?',
            'Appeler ${contact.name} ?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(DriverCopy.current.t('Cancel', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(DriverCopy.current.t('Call', 'Appeler')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final phoneUri = Uri(scheme: 'tel', path: contact.phoneNumber);
    await launchUrl(phoneUri);
  }

  Future<void> _confirmDelete(TrustedContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DriverCopy.current.t(
            'Remove ${contact.name} from trusted contacts?',
            'Retirer ${contact.name} des contacts de confiance ?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(DriverCopy.current.t('Cancel', 'Annuler')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(DriverCopy.current.t('Remove', 'Retirer')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _removeContact(contact);
  }

  void _openAddContactSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AddContactSheet(onSave: (contact) => _addContact(contact)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    final slots = <Widget>[];
    for (final contact in _contacts) {
      slots.add(
        TrustedContactCard(
          contact: contact,
          onCall: () => _confirmCall(contact),
          onDelete: () => _confirmDelete(contact),
        ),
      );
    }
    for (
      var i = _contacts.length;
      i < TrustedContactsService.maxContacts;
      i++
    ) {
      slots.add(AddContactCard(onTap: _openAddContactSheet));
    }

    return FeatureScaffold(
      title: l.t('Trusted Contacts', 'Contacts de confiance'),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(
              alpha: AppColors.isDark(context) ? 0.18 : 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.t(
                    'Add up to 3 trusted contacts. In an emergency, you can '
                        'call them directly.',
                    'Ajoutez jusqu\'à 3 contacts de confiance. En cas d\'urgence, vous '
                        'pouvez les appeler directement.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (var i = 0; i < slots.length; i++) ...[
            slots[i],
            if (i < slots.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.onSave});

  final ValueChanged<TrustedContact> onSave;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(
        () => _error = DriverCopy.current.t(
          'Contacts permission is disabled. Enable it in Settings to '
              'pick a contact, or enter details manually.',
          'L\'autorisation d\'accès aux contacts est désactivée. Activez-la dans '
              'les paramètres pour choisir un contact, ou saisissez les informations manuellement.',
        ),
      );
      return;
    }
    if (!status.isGranted) {
      setState(
        () => _error = DriverCopy.current.t(
          'Contacts permission was denied. Please enter details manually.',
          'L\'autorisation d\'accès aux contacts a été refusée. Veuillez saisir les informations manuellement.',
        ),
      );
      return;
    }

    List<Contact> contacts;
    try {
      contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = DriverCopy.current.t(
          'Could not load contacts. Please enter details manually.',
          'Impossible de charger les contacts. Veuillez saisir les informations manuellement.',
        ),
      );
      return;
    }
    contacts = contacts.where((c) => c.phones.isNotEmpty).toList();

    if (!mounted) return;
    final selected = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContactPickerSheet(contacts: contacts),
    );
    if (selected == null) return;

    setState(() {
      _nameController.text = selected.displayName ?? '';
      _phoneController.text = selected.phones.first.number;
      _error = null;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(
        () => _error = DriverCopy.current.t(
          'Please enter both name and phone number',
          'Veuillez saisir le nom et le numéro de téléphone',
        ),
      );
      return;
    }
    widget.onSave(
      TrustedContact(id: const Uuid().v4(), name: name, phoneNumber: phone),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurfaceFor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.t('Add Trusted Contact', 'Ajouter un contact de confiance'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryFor(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickFromContacts,
                  icon: const Icon(
                    Icons.contact_page_rounded,
                    color: AppColors.purple,
                  ),
                  label: Text(l.t('Choose from Contacts', 'Choisir parmi les contacts')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.purple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        l.t('or enter manually', 'ou saisissez manuellement'),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l.t('Contact Name', 'Nom du contact'),
                    hintText: l.t('e.g. John Doe', 'ex. Jean Dupont'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l.t('Phone Number', 'Numéro de téléphone'),
                    hintText: l.t('e.g. +237 6XX XXX XXX', 'ex. +237 6XX XXX XXX'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l.t('Save Contact', 'Enregistrer le contact')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet({required this.contacts});

  final List<Contact> contacts;

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  late List<Contact> _filtered = widget.contacts;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _filtered = normalized.isEmpty
          ? widget.contacts
          : widget.contacts
                .where(
                  (c) =>
                      (c.displayName ?? '').toLowerCase().contains(normalized),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurfaceFor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.t('Choose a Contact', 'Choisir un contact'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryFor(context),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l.t('Search contacts', 'Rechercher des contacts'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        l.t(
                          'No contacts with a phone number found.',
                          'Aucun contact avec un numéro de téléphone trouvé.',
                        ),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final contact = _filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.purple.withValues(
                              alpha: 0.12,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.purple,
                            ),
                          ),
                          title: Text(
                            contact.displayName ?? l.t('Unknown', 'Inconnu'),
                          ),
                          subtitle: Text(contact.phones.first.number),
                          onTap: () => Navigator.pop(context, contact),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
