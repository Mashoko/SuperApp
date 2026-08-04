import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/inject.dart';
import '../../../call/presentation/viewmodels/call_viewmodel.dart';
import '../../../dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../data/utils/contact_grouping.dart';
import '../../data/utils/contacts_permission_resolution.dart';

class ContactsView extends StatefulWidget {
  const ContactsView({super.key, this.darkTheme = false, this.onNumberCopied});

  /// When true, renders with the dark glass styling used inside the
  /// redesigned dialer sheet. Defaults to false so CallingView's Contacts
  /// tab (the other caller of this widget) is unaffected.
  final bool darkTheme;

  /// Called after "Copy to Dialpad" successfully updates the shared
  /// DialpadViewModel's destination. Only provided by DialpadView (the
  /// redesigned dialer sheet), which uses it to sync its own local
  /// TextEditingController and switch back to the keypad. Null when
  /// embedded in CallingView (its "Copy to Dialpad" keeps today's
  /// existing behavior — just updating the ViewModel — unchanged).
  final VoidCallback? onNumberCopied;

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  List<Contact>? _contacts;
  List<Contact>? _filteredContacts;
  ContactsPermissionState _permissionState = ContactsPermissionState.unknown;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_contacts != null) {
        _filteredContacts = _contacts!.where((contact) {
          final nameMatches =
              contact.displayName.toLowerCase().contains(_searchQuery);
          final phoneMatches = contact.phones.any((phone) => phone.number
              .replaceAll(RegExp(r'[^\d+]'), '')
              .contains(_searchQuery));
          return nameMatches || phoneMatches;
        }).toList();
      }
    });
  }

  Future<void> _fetchContacts({bool showLoadingSpinner = true}) async {
    setState(() {
      if (showLoadingSpinner) _contacts = null;
      _permissionState = ContactsPermissionState.unknown;
    });

    bool isMobile = false;
    try {
      isMobile = Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      isMobile = false;
    }

    if (!isMobile) {
      setState(() {
        _contacts = [];
        _filteredContacts = [];
        _permissionState = ContactsPermissionState.granted;
      });
      return;
    }

    final status = await Permission.contacts.status;
    final resolved = resolvePermissionState(status);
    if (resolved == ContactsPermissionState.granted) {
      final contacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: true);
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _permissionState = resolved;
      });
    } else {
      setState(() => _permissionState = resolved);
    }
  }

  Future<void> _requestPermission() async {
    final result = await Permission.contacts.request();
    final resolved = resolvePermissionState(result);
    if (resolved == ContactsPermissionState.granted) {
      await _fetchContacts();
    } else {
      setState(() => _permissionState = resolved);
    }
  }

  void _onContactTapped(Contact contact) {
    if (contact.phones.isNotEmpty) {
      final number = contact.phones.first.number;
      _showContactOptions(contact, number);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact has no phone number.')),
      );
    }
  }

  void _showContactOptions(Contact contact, String number) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(contact.displayName,
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.call),
                title: Text('Call $number'),
                onTap: () async {
                  Navigator.pop(context);
                  final error = await getIt<CallViewModel>()
                      .makeCall(number, voiceOnly: true);
                  if (!context.mounted || error == null) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy to Dialpad'),
                onTap: () {
                  Navigator.pop(context);
                  final dialpadViewModel =
                      Provider.of<DialpadViewModel>(context, listen: false);
                  dialpadViewModel.setDestination(number);
                  widget.onNumberCopied?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Number copied to Dialpad')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionEmptyState() {
    return widget.darkTheme
        ? _buildPermissionEmptyStateDark()
        : _buildPermissionEmptyStateLight();
  }

  Widget _buildPermissionEmptyStateLight() {
    final isPermanentlyDenied =
        _permissionState == ContactsPermissionState.permanentlyDenied;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.contacts_outlined,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    isPermanentlyDenied
                        ? 'Contacts access is disabled. Enable it in Settings to see your contacts here.'
                        : 'Allow access to your contacts to see them here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        isPermanentlyDenied ? openAppSettings : _requestPermission,
                    child: const Text('Grant Access'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionEmptyStateDark() {
    final isPermanentlyDenied =
        _permissionState == ContactsPermissionState.permanentlyDenied;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.contacts_outlined,
                      size: 56, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    isPermanentlyDenied
                        ? 'Contacts access is disabled. Enable it in Settings to see your contacts here.'
                        : 'Allow access to your contacts to see them here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        isPermanentlyDenied ? openAppSettings : _requestPermission,
                    child: const Text('Grant Access'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsList() {
    final contacts = _filteredContacts ?? const [];
    if (contacts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Text(
                'No contacts found',
                style:
                    widget.darkTheme ? const TextStyle(color: Colors.white54) : null,
              ),
            ),
          ),
        ],
      );
    }

    final grouped = groupContactsByLetter(contacts);
    final letters = grouped.keys.toList();
    final headerColor = widget.darkTheme ? Colors.white54 : Colors.grey;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: letters.length,
      itemBuilder: (context, letterIndex) {
        final letter = letters[letterIndex];
        final letterContacts = grouped[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                letter,
                style: TextStyle(fontWeight: FontWeight.bold, color: headerColor),
              ),
            ),
            for (final contact in letterContacts)
              ListTile(
                leading: (contact.photoOrThumbnail != null)
                    ? CircleAvatar(
                        backgroundImage:
                            MemoryImage(contact.photoOrThumbnail!))
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(contact.displayName,
                    style: widget.darkTheme
                        ? const TextStyle(color: Colors.white)
                        : null),
                subtitle: contact.phones.isNotEmpty
                    ? Text(contact.phones.first.number,
                        style: widget.darkTheme
                            ? const TextStyle(color: Colors.white54)
                            : null)
                    : null,
                onTap: () => _onContactTapped(contact),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.darkTheme) {
      return Column(
        children: [
          _buildSearchField(dark: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchContacts(showLoadingSpinner: false),
              child: _permissionState == ContactsPermissionState.denied ||
                      _permissionState ==
                          ContactsPermissionState.permanentlyDenied
                  ? _buildPermissionEmptyState()
                  : _contacts == null
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white70))
                      : _buildContactsList(),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import Contacts',
            onPressed: () {
              _fetchContacts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing contacts...')),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildSearchField(dark: false),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchContacts(showLoadingSpinner: false),
              child: _permissionState == ContactsPermissionState.denied ||
                      _permissionState ==
                          ContactsPermissionState.permanentlyDenied
                  ? _buildPermissionEmptyState()
                  : _contacts == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContactsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({required bool dark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.transparent,
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: dark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
          prefixIcon: Icon(Icons.search, color: dark ? Colors.white54 : null),
          filled: true,
          fillColor: dark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: dark ? Colors.white54 : null),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }
}
