import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';


import '../../../../core/di/inject.dart';
import '../../../call/presentation/viewmodels/call_viewmodel.dart';
import '../../../dialpad/presentation/viewmodels/dialpad_viewmodel.dart';

class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  List<Contact>? _contacts;
  List<Contact>? _filteredContacts;
  bool _permissionDenied = false;
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
          final nameMatches = contact.displayName.toLowerCase().contains(_searchQuery);
          final phoneMatches = contact.phones.any((phone) => 
            phone.number.replaceAll(RegExp(r'[^\d+]'), '').contains(_searchQuery)
          );
          return nameMatches || phoneMatches;
        }).toList();
      }
    });
  }

  Future<void> _fetchContacts() async {
    setState(() => _contacts = null); // Trigger loading
    // Basic Platform Check to avoid MissingPluginException on Linux/Windows
    bool isMobile = false; 
    try {
      isMobile = Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      // Platform.isAndroid/iOS might throw if not on correct platform context or web
      isMobile = false;
    }

    if (!isMobile) {
      // On Desktop/Web, just show empty or mock contacts for now to avoid crash
      setState(() {
        _contacts = []; 
        _permissionDenied = false; // Not denied, just not applicable
      });
      return; 
    }

    if (!await FlutterContacts.requestPermission(readonly: true)) {
      setState(() => _permissionDenied = true);
    } else {
      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
      });
    }
  }

  void _onContactTapped(Contact contact) {
    if (contact.phones.isNotEmpty) {
      final number = contact.phones.first.number;
      // Option to call directly or fill dialpad
      // For now, let's call directly or show a sheet
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
              Text(contact.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.call),
                title: Text('Call $number'),
                onTap: () {
                  Navigator.pop(context);
                  // Use CallViewModel to make call
                  getIt<CallViewModel>().makeCall(number, voiceOnly: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy to Dialpad'),
                onTap: () {
                  Navigator.pop(context);
                  // This is a bit tricky since Dialpad is a separate tab.
                  // We can update DialpadViewModel
                  final dialpadViewModel = Provider.of<DialpadViewModel>(context, listen: false);
                  dialpadViewModel.setDestination(number);
                  // The user will see it when they switch to Dialpad tab.
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

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return const Center(child: Text('Permission denied'));
    }
    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_contacts!.isEmpty) {
      return const Center(child: Text('No contacts found'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black, // For text/icon color
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
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          Expanded(
            child: _filteredContacts != null && _filteredContacts!.isEmpty
                ? const Center(child: Text('No contacts found'))
                : ListView.builder(
                    itemCount: _filteredContacts?.length ?? 0,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts![index];
                      return ListTile(
                        leading: (contact.photoOrThumbnail != null)
                            ? CircleAvatar(backgroundImage: MemoryImage(contact.photoOrThumbnail!))
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(contact.displayName),
                        subtitle: contact.phones.isNotEmpty ? Text(contact.phones.first.number) : null,
                        onTap: () => _onContactTapped(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
